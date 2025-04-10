/*
  # Fix attempt count tracking and session statistics

  1. Changes
    - Remove v_attempt_count column from word_attempts table
    - Update trigger function to calculate attempt count dynamically
    - Fix session statistics calculation
    
  2. Purpose
    - Fix error with non-existent column
    - Ensure proper attempt counting
    - Maintain accurate session statistics
*/

-- Drop the problematic column if it exists
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'word_attempts' 
    AND column_name = 'v_attempt_count'
  ) THEN
    ALTER TABLE word_attempts DROP COLUMN v_attempt_count;
  END IF;
END $$;

-- Update the game stats trigger function to calculate attempt count dynamically
CREATE OR REPLACE FUNCTION update_game_session_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  session_stats RECORD;
BEGIN
  -- Calculate all statistics in one query
  SELECT 
    COUNT(*) FILTER (WHERE is_correct) as correct_count,
    AVG(response_time_ms) as avg_response_time,
    COUNT(*) as total_attempts
  INTO session_stats
  FROM word_attempts
  WHERE session_id = NEW.session_id;

  -- Update game session with new statistics
  UPDATE game_sessions
  SET 
    correct_words = session_stats.correct_count,
    average_response_time = session_stats.avg_response_time
  WHERE session_id = NEW.session_id;

  -- Log statistics update
  RAISE LOG 'Updated game session stats: session_id=%, correct=%, avg_time=%ms, attempts=%',
    NEW.session_id,
    session_stats.correct_count,
    session_stats.avg_response_time,
    session_stats.total_attempts;

  RETURN NEW;
END;
$$;

-- Recreate the trigger
DROP TRIGGER IF EXISTS update_game_stats_trigger ON word_attempts;
CREATE TRIGGER update_game_stats_trigger
  AFTER INSERT OR UPDATE ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_game_session_stats();

-- Recalculate statistics for all existing sessions
WITH session_statistics AS (
  SELECT 
    session_id,
    COUNT(*) FILTER (WHERE is_correct) as correct_count,
    AVG(response_time_ms) as avg_response_time
  FROM word_attempts
  GROUP BY session_id
)
UPDATE game_sessions gs
SET
  correct_words = ss.correct_count,
  average_response_time = ss.avg_response_time
FROM session_statistics ss
WHERE gs.session_id = ss.session_id;