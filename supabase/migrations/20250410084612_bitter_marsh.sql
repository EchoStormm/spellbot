/*
  # Fix game session statistics and word counting

  1. Changes
    - Update trigger function to properly count total words
    - Fix session completion check
    - Ensure all word attempts are counted
    
  2. Purpose
    - Fix incorrect word count display
    - Ensure all 10 words are properly tracked
    - Maintain accurate game statistics
*/

-- Drop existing trigger first
DROP TRIGGER IF EXISTS update_session_stats_trigger ON word_attempts;

-- Update the session stats function to properly count words
CREATE OR REPLACE FUNCTION public.update_session_stats()
RETURNS TRIGGER AS $$
DECLARE
  v_total_attempts INTEGER;
  v_correct_count INTEGER;
  v_avg_response_time FLOAT;
  v_total_words INTEGER;
BEGIN
  -- Get the total words for this session
  SELECT total_words INTO v_total_words
  FROM public.game_sessions
  WHERE session_id = NEW.session_id;

  -- Calculate statistics
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE is_correct),
    AVG(response_time_ms)::float
  INTO 
    v_total_attempts,
    v_correct_count,
    v_avg_response_time
  FROM public.word_attempts
  WHERE session_id = NEW.session_id;

  -- Update game session statistics
  UPDATE public.game_sessions
  SET 
    correct_words = v_correct_count,
    average_response_time = v_avg_response_time
  WHERE session_id = NEW.session_id;

  -- Check if all words have been attempted
  IF v_total_attempts = v_total_words THEN
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
CREATE TRIGGER update_session_stats_trigger
  AFTER INSERT OR UPDATE ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_session_stats();

-- Fix any existing sessions with incorrect counts
UPDATE public.game_sessions gs
SET
  correct_words = (
    SELECT COUNT(*) 
    FROM public.word_attempts wa
    WHERE wa.session_id = gs.session_id
    AND wa.is_correct = true
  ),
  average_response_time = (
    SELECT AVG(wa.response_time_ms)::float
    FROM public.word_attempts wa
    WHERE wa.session_id = gs.session_id
  )
WHERE gs.completed = true;