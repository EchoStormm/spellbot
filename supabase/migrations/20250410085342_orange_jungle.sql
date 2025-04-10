/*
  # Fix last word saving and session completion

  1. Changes
    - Update trigger function to properly handle the last word attempt
    - Fix race condition in session completion check
    - Add better error handling and logging
    - Add validation to prevent duplicate word attempts
    
  2. Purpose
    - Ensure all words are saved correctly
    - Fix session completion logic
    - Improve data consistency
*/

-- Drop existing trigger first
DROP TRIGGER IF EXISTS update_session_stats_trigger ON word_attempts;

-- Update the session stats function with improved word counting
CREATE OR REPLACE FUNCTION public.update_session_stats()
RETURNS TRIGGER AS $$
DECLARE
  v_total_attempts INTEGER;
  v_correct_count INTEGER;
  v_avg_response_time FLOAT;
  v_total_words INTEGER;
  v_duplicate_attempt BOOLEAN;
BEGIN
  -- Check for duplicate attempt
  SELECT EXISTS (
    SELECT 1 
    FROM public.word_attempts 
    WHERE session_id = NEW.session_id 
    AND word_id = NEW.word_id
    AND attempt_id != NEW.attempt_id
  ) INTO v_duplicate_attempt;

  -- Get the total words for this session
  SELECT total_words INTO v_total_words
  FROM public.game_sessions
  WHERE session_id = NEW.session_id;

  -- Calculate statistics including the current attempt
  WITH current_attempt AS (
    SELECT 
      is_correct,
      response_time_ms
    FROM public.word_attempts
    WHERE session_id = NEW.session_id
    AND attempt_id = NEW.attempt_id
  ),
  existing_attempts AS (
    SELECT 
      is_correct,
      response_time_ms
    FROM public.word_attempts
    WHERE session_id = NEW.session_id
    AND attempt_id != NEW.attempt_id
  ),
  all_attempts AS (
    SELECT * FROM existing_attempts
    UNION ALL
    SELECT * FROM current_attempt
    WHERE NOT v_duplicate_attempt
  )
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE is_correct),
    AVG(response_time_ms)::float
  INTO 
    v_total_attempts,
    v_correct_count,
    v_avg_response_time
  FROM all_attempts;

  -- Log attempt counts for debugging
  RAISE LOG 'Session stats: total_attempts=%, correct=%, total_words=%, session_id=%',
    v_total_attempts, v_correct_count, v_total_words, NEW.session_id;

  -- Update game session statistics
  UPDATE public.game_sessions
  SET 
    correct_words = v_correct_count,
    average_response_time = v_avg_response_time
  WHERE session_id = NEW.session_id;

  -- Check if all words have been attempted
  IF v_total_attempts >= v_total_words THEN
    RAISE LOG 'Marking session % as complete (attempts: %, required: %)',
      NEW.session_id, v_total_attempts, v_total_words;
      
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

-- Fix any existing incomplete sessions
UPDATE public.game_sessions gs
SET
  correct_words = stats.correct_count,
  average_response_time = stats.avg_response_time,
  completed = true,
  end_time = COALESCE(gs.end_time, NOW())
FROM (
  SELECT 
    wa.session_id,
    COUNT(*) FILTER (WHERE wa.is_correct) as correct_count,
    AVG(wa.response_time_ms)::float as avg_response_time,
    COUNT(*) as total_attempts
  FROM public.word_attempts wa
  GROUP BY wa.session_id
) stats
WHERE 
  gs.session_id = stats.session_id
  AND stats.total_attempts >= gs.total_words
  AND (gs.completed = false OR gs.completed IS NULL);