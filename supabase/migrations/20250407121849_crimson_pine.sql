/*
  # Fix game completion status tracking

  1. Changes
    - Add function to ensure game sessions are properly marked as completed
    - Add trigger to automatically mark sessions as completed when all words are attempted
    - Update existing incomplete sessions that should be marked complete

  2. Purpose
    - Fix issue where completed games appear as incomplete in Recent Games
    - Ensure consistent game completion status
    - Clean up any incorrectly marked sessions
*/

-- Function to check if a session should be marked as complete
CREATE OR REPLACE FUNCTION check_session_completion()
RETURNS TRIGGER AS $$
DECLARE
  attempt_count INTEGER;
  total_words INTEGER;
BEGIN
  -- Get the total number of attempts for this session
  SELECT COUNT(*) INTO attempt_count
  FROM word_attempts
  WHERE session_id = NEW.session_id;

  -- Get the total words for this session
  SELECT total_words INTO total_words
  FROM game_sessions
  WHERE session_id = NEW.session_id;

  -- If we've attempted all words, mark the session as complete
  IF attempt_count = total_words THEN
    UPDATE game_sessions
    SET 
      completed = true,
      end_time = COALESCE(end_time, now())
    WHERE session_id = NEW.session_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to check completion after each word attempt
DROP TRIGGER IF EXISTS check_session_completion_trigger ON word_attempts;
CREATE TRIGGER check_session_completion_trigger
  AFTER INSERT ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION check_session_completion();

-- Fix any existing sessions that should be marked as complete
WITH completed_sessions AS (
  SELECT 
    gs.session_id,
    gs.total_words,
    COUNT(wa.attempt_id) as attempt_count
  FROM game_sessions gs
  JOIN word_attempts wa ON gs.session_id = wa.session_id
  WHERE gs.completed = false
  GROUP BY gs.session_id, gs.total_words
  HAVING COUNT(wa.attempt_id) = gs.total_words
)
UPDATE game_sessions
SET 
  completed = true,
  end_time = COALESCE(end_time, now())
FROM completed_sessions cs
WHERE game_sessions.session_id = cs.session_id;