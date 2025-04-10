/*
  # Fix average response time column

  1. Changes
    - Ensure average_response_time column exists in game_sessions table
    - Update trigger function to use correct column name
    - Clean up any duplicate columns
    - Update existing data
    
  2. Purpose
    - Fix "column average_response_time does not exist" error
    - Ensure consistent column naming
    - Maintain data integrity
*/

-- First, ensure we have the correct column
ALTER TABLE game_sessions
ADD COLUMN IF NOT EXISTS average_response_time double precision DEFAULT 0;

-- Drop any old/duplicate columns if they exist
ALTER TABLE game_sessions
DROP COLUMN IF EXISTS session_average_response_time;

ALTER TABLE user_statistics
DROP COLUMN IF EXISTS statistics_average_response_time;

-- Update the session stats trigger function
CREATE OR REPLACE FUNCTION public.update_session_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update game session statistics
  UPDATE public.game_sessions
  SET 
    correct_words = (
      SELECT COUNT(*) 
      FROM public.word_attempts 
      WHERE session_id = NEW.session_id AND is_correct = true
    ),
    average_response_time = (
      SELECT AVG(response_time_ms)::double precision
      FROM public.word_attempts
      WHERE session_id = NEW.session_id
    )
  WHERE session_id = NEW.session_id;
  
  -- Check if session should be completed
  IF (
    SELECT COUNT(*)
    FROM public.word_attempts
    WHERE session_id = NEW.session_id
  ) = (
    SELECT total_words
    FROM public.game_sessions
    WHERE session_id = NEW.session_id
  ) THEN
    UPDATE public.game_sessions
    SET 
      completed = true,
      end_time = COALESCE(end_time, NOW())
    WHERE session_id = NEW.session_id
    AND (completed = false OR completed IS NULL);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS update_session_stats_trigger ON word_attempts;
CREATE TRIGGER update_session_stats_trigger
  AFTER INSERT OR UPDATE ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_session_stats();

-- Update existing sessions to ensure data consistency
UPDATE public.game_sessions gs
SET
  average_response_time = (
    SELECT AVG(wa.response_time_ms)::double precision
    FROM public.word_attempts wa
    WHERE wa.session_id = gs.session_id
  ),
  correct_words = (
    SELECT COUNT(*)
    FROM public.word_attempts wa
    WHERE wa.session_id = gs.session_id
    AND wa.is_correct = true
  )
WHERE gs.completed = true;