/*
  # Fix ghost game sessions

  1. Changes
    - Add cleanup function for abandoned sessions
    - Improve session completion validation
    - Add automatic cleanup on session start
    
  2. Purpose
    - Fix issue with incomplete sessions appearing
    - Clean up abandoned sessions
    - Ensure accurate game statistics
*/

-- Function to clean up abandoned sessions
CREATE OR REPLACE FUNCTION cleanup_abandoned_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete word attempts for abandoned sessions
  DELETE FROM word_attempts wa
  WHERE wa.session_id IN (
    SELECT gs.session_id
    FROM game_sessions gs
    WHERE 
      (gs.completed = false OR gs.completed IS NULL)
      AND gs.created_at < NOW() - INTERVAL '1 hour'
      AND NOT EXISTS (
        SELECT 1 
        FROM word_attempts wa2 
        WHERE wa2.session_id = gs.session_id
        AND wa2.created_at > NOW() - INTERVAL '15 minutes'
      )
  );

  -- Delete abandoned sessions
  DELETE FROM game_sessions
  WHERE 
    (completed = false OR completed IS NULL)
    AND created_at < NOW() - INTERVAL '1 hour'
    AND NOT EXISTS (
      SELECT 1 
      FROM word_attempts wa 
      WHERE wa.session_id = game_sessions.session_id
      AND wa.created_at > NOW() - INTERVAL '15 minutes'
    );
END;
$$;

-- Function to validate and initialize new game sessions
CREATE OR REPLACE FUNCTION validate_new_game_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Clean up any abandoned sessions for this user
  DELETE FROM game_sessions
  WHERE 
    user_id = NEW.user_id
    AND (completed = false OR completed IS NULL)
    AND created_at < NOW() - INTERVAL '1 hour';
    
  RETURN NEW;
END;
$$;

-- Create trigger for new game session validation
CREATE TRIGGER validate_new_game_session_trigger
  BEFORE INSERT ON game_sessions
  FOR EACH ROW
  EXECUTE FUNCTION validate_new_game_session();

-- Update session completion check to be more strict
CREATE OR REPLACE FUNCTION check_session_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_words INTEGER;
  v_attempt_count INTEGER;
  v_last_attempt_time TIMESTAMPTZ;
BEGIN
  -- Get the total words and validate session
  SELECT 
    gs.total_words,
    MAX(wa.created_at)
  INTO 
    v_total_words,
    v_last_attempt_time
  FROM game_sessions gs
  LEFT JOIN word_attempts wa ON wa.session_id = gs.session_id
  WHERE gs.session_id = NEW.session_id
  GROUP BY gs.total_words;

  IF v_total_words IS NULL THEN
    RETURN NEW;
  END IF;

  -- Count valid attempts
  SELECT COUNT(*)
  INTO v_attempt_count
  FROM word_attempts wa
  WHERE 
    wa.session_id = NEW.session_id
    AND wa.created_at >= (
      SELECT gs.created_at 
      FROM game_sessions gs 
      WHERE gs.session_id = NEW.session_id
    );

  -- Mark session as complete if all words attempted
  IF v_attempt_count = v_total_words THEN
    UPDATE game_sessions gs
    SET 
      completed = true,
      end_time = COALESCE(gs.end_time, NOW())
    WHERE 
      gs.session_id = NEW.session_id
      AND (gs.completed = false OR gs.completed IS NULL);
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

-- Clean up any existing ghost sessions
SELECT cleanup_abandoned_sessions();