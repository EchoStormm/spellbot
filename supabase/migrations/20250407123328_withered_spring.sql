/*
  # Fix word attempts display and add foreign key constraints

  1. Changes
    - Add foreign key constraint between word_attempts and game_sessions
    - Add index on session_id for better query performance
    - Add trigger to update game_sessions statistics on word attempt insert
    - Fix any orphaned word attempts
    
  2. Security
    - Maintain existing RLS policies
    - Add referential integrity
*/

-- Add index on session_id for better performance
CREATE INDEX IF NOT EXISTS word_attempts_session_id_idx ON word_attempts(session_id);

-- Add foreign key constraint if it doesn't exist
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.table_constraints 
    WHERE constraint_name = 'word_attempts_session_id_fkey'
  ) THEN
    ALTER TABLE word_attempts
    ADD CONSTRAINT word_attempts_session_id_fkey
    FOREIGN KEY (session_id) REFERENCES game_sessions(session_id)
    ON DELETE CASCADE;
  END IF;
END $$;

-- Function to update game session statistics
CREATE OR REPLACE FUNCTION update_game_session_stats()
RETURNS TRIGGER AS $$
DECLARE
  correct_count INTEGER;
  avg_response_time FLOAT;
BEGIN
  -- Calculate new statistics
  SELECT 
    COUNT(*) FILTER (WHERE is_correct = true),
    AVG(response_time_ms)
  INTO 
    correct_count,
    avg_response_time
  FROM word_attempts
  WHERE session_id = NEW.session_id;

  -- Update game session
  UPDATE game_sessions
  SET 
    correct_words = correct_count,
    average_response_time = avg_response_time
  WHERE session_id = NEW.session_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for updating game session stats
DROP TRIGGER IF EXISTS update_game_stats_trigger ON word_attempts;
CREATE TRIGGER update_game_stats_trigger
  AFTER INSERT OR UPDATE ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_game_session_stats();

-- Clean up any orphaned word attempts
DELETE FROM word_attempts wa
WHERE NOT EXISTS (
  SELECT 1 
  FROM game_sessions gs 
  WHERE gs.session_id = wa.session_id
);

-- Recalculate statistics for all existing game sessions
UPDATE game_sessions gs
SET
  correct_words = stats.correct_count,
  average_response_time = stats.avg_response_time
FROM (
  SELECT 
    session_id,
    COUNT(*) FILTER (WHERE is_correct = true) as correct_count,
    AVG(response_time_ms) as avg_response_time
  FROM word_attempts
  GROUP BY session_id
) stats
WHERE gs.session_id = stats.session_id;