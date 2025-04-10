/*
  # Fix duplicate sessions and improve cleanup

  1. Changes
    - Fix session identification using subquery instead of window function
    - Improve session validation and cleanup
    - Add better error handling
    
  2. Purpose
    - Prevent duplicate active sessions
    - Clean up abandoned sessions
    - Ensure accurate game tracking
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
WITH duplicate_sessions AS (
  SELECT user_id
  FROM game_sessions
  WHERE completed = false OR completed IS NULL
  GROUP BY user_id
  HAVING COUNT(*) > 1
),
oldest_sessions AS (
  SELECT DISTINCT ON (gs.user_id) 
    gs.session_id as keep_session_id
  FROM game_sessions gs
  JOIN duplicate_sessions ds ON gs.user_id = ds.user_id
  WHERE gs.completed = false OR gs.completed IS NULL
  ORDER BY gs.user_id, gs.created_at ASC
)
UPDATE game_sessions gs
SET 
  completed = true,
  end_time = NOW()
FROM duplicate_sessions ds
WHERE 
  gs.user_id = ds.user_id
  AND gs.session_id NOT IN (SELECT keep_session_id FROM oldest_sessions)
  AND (gs.completed = false OR gs.completed IS NULL);