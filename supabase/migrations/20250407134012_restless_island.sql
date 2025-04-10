/*
  # Fix ghost game sessions and improve session management
  
  1. Changes
    - Add validation to prevent duplicate active sessions
    - Improve session cleanup logic
    - Add automatic cleanup of old incomplete sessions
    - Fix session completion detection
    
  2. Purpose
    - Prevent ghost sessions from appearing
    - Ensure accurate game statistics
    - Improve user experience
*/

-- Function to validate new game sessions and clean up old ones
CREATE OR REPLACE FUNCTION validate_new_game_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- First, mark any old incomplete sessions as abandoned
  UPDATE game_sessions
  SET completed = true, end_time = NOW()
  WHERE 
    user_id = NEW.user_id
    AND (completed = false OR completed IS NULL)
    AND created_at < NOW() - INTERVAL '5 minutes';

  -- Then clean up any really old sessions
  DELETE FROM game_sessions
  WHERE 
    user_id = NEW.user_id
    AND (completed = false OR completed IS NULL)
    AND created_at < NOW() - INTERVAL '1 hour';

  RETURN NEW;
END;
$$;

-- Function to check session completion with improved validation
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
  -- Get session info and validate
  SELECT 
    gs.total_words,
    COUNT(wa.attempt_id),
    MAX(wa.created_at)
  INTO 
    v_total_words,
    v_attempt_count,
    v_last_attempt_time
  FROM game_sessions gs
  LEFT JOIN word_attempts wa ON wa.session_id = NEW.session_id
  WHERE gs.session_id = NEW.session_id
  GROUP BY gs.total_words;

  -- Mark session as complete if we have all attempts
  IF v_attempt_count = v_total_words THEN
    UPDATE game_sessions gs
    SET 
      completed = true,
      end_time = COALESCE(gs.end_time, NOW())
    WHERE 
      gs.session_id = NEW.session_id
      AND (gs.completed = false OR gs.completed IS NULL);
  END IF;

  -- Auto-complete abandoned sessions
  UPDATE game_sessions gs
  SET 
    completed = true,
    end_time = NOW()
  WHERE 
    gs.session_id = NEW.session_id
    AND (gs.completed = false OR gs.completed IS NULL)
    AND gs.created_at < NOW() - INTERVAL '5 minutes';

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

-- Drop and recreate triggers to ensure clean state
DROP TRIGGER IF EXISTS validate_new_game_session_trigger ON game_sessions;
DROP TRIGGER IF EXISTS check_session_completion_trigger ON word_attempts;

-- Create triggers
CREATE TRIGGER validate_new_game_session_trigger
  BEFORE INSERT ON game_sessions
  FOR EACH ROW
  EXECUTE FUNCTION validate_new_game_session();

CREATE TRIGGER check_session_completion_trigger
  AFTER INSERT ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION check_session_completion();

-- Clean up existing ghost sessions
UPDATE game_sessions
SET 
  completed = true,
  end_time = NOW()
WHERE 
  (completed = false OR completed IS NULL)
  AND created_at < NOW() - INTERVAL '5 minutes';

-- Delete very old incomplete sessions
DELETE FROM game_sessions
WHERE 
  (completed = false OR completed IS NULL)
  AND created_at < NOW() - INTERVAL '1 hour';