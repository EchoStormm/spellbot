/*
  # Fix session handling and prevent duplicates

  1. Changes
    - Improve session validation to prevent duplicates
    - Add better session completion logic
    - Clean up any existing duplicate sessions
    
  2. Purpose
    - Ensure only one active session per user
    - Fix ghost sessions
    - Improve data consistency
*/

-- Function to validate new game sessions and prevent duplicates
CREATE OR REPLACE FUNCTION validate_new_game_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- First, complete any existing active sessions for this user
  UPDATE game_sessions
  SET 
    completed = true,
    end_time = NOW()
  WHERE 
    user_id = NEW.user_id
    AND (completed = false OR completed IS NULL);

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
BEGIN
  -- Get session info and validate
  SELECT 
    gs.total_words,
    COUNT(wa.attempt_id)
  INTO 
    v_total_words,
    v_attempt_count
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

  RETURN NEW;
END;
$$;

-- Drop existing triggers
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

-- Complete any existing duplicate sessions
UPDATE game_sessions gs1
SET 
  completed = true,
  end_time = NOW()
FROM game_sessions gs2
WHERE 
  gs1.user_id = gs2.user_id
  AND gs1.session_id > gs2.session_id
  AND (gs1.completed = false OR gs1.completed IS NULL);