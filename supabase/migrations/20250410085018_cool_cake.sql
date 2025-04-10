/*
  # Fix last word recording in game sessions

  1. Changes
    - Update trigger to properly handle session completion
    - Fix word attempt counting logic
    - Add better error handling
    
  2. Purpose
    - Ensure all words are properly recorded
    - Fix issue with last word not being saved
    - Maintain accurate game statistics
*/

-- Drop existing trigger first
DROP TRIGGER IF EXISTS update_session_stats_trigger ON word_attempts;

-- Update the session stats function to properly handle all words
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

  -- Calculate statistics including the current attempt
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE is_correct),
    AVG(response_time_ms)::float
  INTO 
    v_total_attempts,
    v_correct_count,
    v_avg_response_time
  FROM (
    -- Include both existing attempts and the current one
    SELECT 
      is_correct,
      response_time_ms
    FROM public.word_attempts
    WHERE session_id = NEW.session_id
    UNION ALL
    SELECT 
      NEW.is_correct,
      NEW.response_time_ms
    WHERE NOT EXISTS (
      SELECT 1 
      FROM public.word_attempts 
      WHERE session_id = NEW.session_id 
      AND word_id = NEW.word_id
    )
  ) attempts;

  -- Update game session statistics
  UPDATE public.game_sessions
  SET 
    correct_words = v_correct_count,
    average_response_time = v_avg_response_time
  WHERE session_id = NEW.session_id;

  -- Check if all words have been attempted (including current one)
  IF v_total_attempts >= v_total_words THEN
    UPDATE public.game_sessions
    SET 
      completed = true,
      end_time = COALESCE(end_time, NOW())
    WHERE session_id = NEW.session_id
    AND (completed = false OR completed IS NULL);
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but allow the transaction to continue
    RAISE WARNING 'Error in update_session_stats: %', SQLERRM;
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
  ),
  completed = true,
  end_time = COALESCE(gs.end_time, NOW())
WHERE 
  (SELECT COUNT(*) FROM public.word_attempts wa WHERE wa.session_id = gs.session_id) >= gs.total_words
  AND (gs.completed = false OR gs.completed IS NULL);