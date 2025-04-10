/*
  # Fix ambiguous column reference in trigger function

  1. Changes
    - Update update_game_session_stats function to use qualified column names
    - Add explicit table references to avoid ambiguity
    - Maintain existing functionality
    
  2. Purpose
    - Fix "column reference total_words is ambiguous" error
    - Improve query clarity and maintainability
*/

-- Drop existing trigger first
DROP TRIGGER IF EXISTS update_game_stats_trigger ON word_attempts;

-- Update the function with qualified column names
CREATE OR REPLACE FUNCTION update_game_session_stats()
RETURNS TRIGGER AS $$
DECLARE
  correct_count INTEGER;
  avg_response_time FLOAT;
  session_total_words INTEGER;
BEGIN
  -- Get the total_words from game_sessions first
  SELECT gs.total_words 
  INTO session_total_words
  FROM game_sessions gs
  WHERE gs.session_id = NEW.session_id;

  -- Calculate new statistics with explicit table references
  SELECT 
    COUNT(*) FILTER (WHERE wa.is_correct = true),
    AVG(wa.response_time_ms)
  INTO 
    correct_count,
    avg_response_time
  FROM word_attempts wa
  WHERE wa.session_id = NEW.session_id;

  -- Update game session with explicit column references
  UPDATE game_sessions gs
  SET 
    correct_words = correct_count,
    average_response_time = avg_response_time
  WHERE gs.session_id = NEW.session_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
CREATE TRIGGER update_game_stats_trigger
  AFTER INSERT OR UPDATE ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_game_session_stats();

-- Reapply the trigger to existing sessions
UPDATE word_attempts
SET response_time_ms = response_time_ms
WHERE session_id IN (
  SELECT session_id 
  FROM game_sessions 
  WHERE completed = true
);