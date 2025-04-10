/*
  # Fix ambiguous column references in triggers

  1. Changes
    - Update trigger functions to explicitly specify table names for ambiguous columns
    - Recreate triggers with fixed column references
    - No data modification, only trigger logic updates

  2. Security
    - No changes to security policies
    - Maintains existing RLS settings
*/

-- Drop existing triggers first
DROP TRIGGER IF EXISTS update_game_stats_trigger ON word_attempts;
DROP TRIGGER IF EXISTS check_session_completion_trigger ON word_attempts;

-- Update the game stats trigger function
CREATE OR REPLACE FUNCTION update_game_session_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update game session statistics with explicit table references
  UPDATE game_sessions
  SET 
    correct_words = (
      SELECT COUNT(*) 
      FROM word_attempts wa
      WHERE wa.session_id = NEW.session_id 
      AND wa.is_correct = true
    ),
    average_response_time = (
      SELECT AVG(response_time_ms)
      FROM word_attempts wa
      WHERE wa.session_id = NEW.session_id
    )
  WHERE session_id = NEW.session_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update the session completion check function
CREATE OR REPLACE FUNCTION check_session_completion()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if we've reached the total number of words with explicit table reference
  IF (
    SELECT COUNT(*)
    FROM word_attempts wa
    WHERE wa.session_id = NEW.session_id
  ) = (
    SELECT gs.total_words
    FROM game_sessions gs
    WHERE gs.session_id = NEW.session_id
  ) THEN
    UPDATE game_sessions
    SET 
      completed = true,
      end_time = NOW()
    WHERE session_id = NEW.session_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the triggers
CREATE TRIGGER update_game_stats_trigger
AFTER INSERT OR UPDATE ON word_attempts
FOR EACH ROW
EXECUTE FUNCTION update_game_session_stats();

CREATE TRIGGER check_session_completion_trigger
AFTER INSERT ON word_attempts
FOR EACH ROW
EXECUTE FUNCTION check_session_completion();