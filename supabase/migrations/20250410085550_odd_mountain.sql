/*
  # Fix last word saving in game sessions
  
  1. Changes
    - Update trigger to save word attempt before checking completion
    - Fix race condition in session completion check
    - Add better error handling and logging
    
  2. Purpose
    - Ensure all words are saved correctly
    - Fix session completion timing
    - Improve data consistency
*/

-- Drop existing trigger first
DROP TRIGGER IF EXISTS update_session_stats_trigger ON word_attempts;

-- Update the session stats function to handle word saving properly
CREATE OR REPLACE FUNCTION public.update_session_stats()
RETURNS TRIGGER AS $$
DECLARE
  v_total_words INTEGER;
  v_attempt_count INTEGER;
  v_correct_count INTEGER;
  v_avg_response_time FLOAT;
BEGIN
  -- Get session info first
  SELECT total_words 
  INTO v_total_words
  FROM public.game_sessions
  WHERE session_id = NEW.session_id;

  -- Calculate statistics AFTER the current attempt is saved
  WITH attempt_stats AS (
    SELECT 
      COUNT(*) as total_attempts,
      COUNT(*) FILTER (WHERE is_correct) as correct_attempts,
      AVG(response_time_ms)::float as avg_time
    FROM public.word_attempts
    WHERE session_id = NEW.session_id
  )
  SELECT 
    total_attempts,
    correct_attempts,
    avg_time
  INTO 
    v_attempt_count,
    v_correct_count,
    v_avg_response_time
  FROM attempt_stats;

  -- Log the counts for debugging
  RAISE LOG 'Word attempt: session=%, word=%, attempt_count=%, total_words=%',
    NEW.session_id, NEW.word_id, v_attempt_count, v_total_words;

  -- Update game session statistics
  UPDATE public.game_sessions
  SET 
    correct_words = v_correct_count,
    average_response_time = v_avg_response_time
  WHERE session_id = NEW.session_id;

  -- Mark session as complete if we have all attempts
  -- Note: We check for equality now since we're counting after saving
  IF v_attempt_count = v_total_words THEN
    RAISE LOG 'Completing session: %, attempts=%, words=%',
      NEW.session_id, v_attempt_count, v_total_words;

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
    RAISE WARNING 'Error in update_session_stats: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger to run AFTER the word attempt is saved
CREATE TRIGGER update_session_stats_trigger
  AFTER INSERT ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_session_stats();

-- Fix any existing sessions that are missing their completion status
WITH session_stats AS (
  SELECT 
    gs.session_id,
    gs.total_words,
    COUNT(wa.attempt_id) as attempt_count,
    COUNT(*) FILTER (WHERE wa.is_correct) as correct_count,
    AVG(wa.response_time_ms)::float as avg_time
  FROM public.game_sessions gs
  LEFT JOIN public.word_attempts wa ON wa.session_id = gs.session_id
  GROUP BY gs.session_id, gs.total_words
)
UPDATE public.game_sessions gs
SET
  completed = true,
  end_time = COALESCE(gs.end_time, NOW()),
  correct_words = ss.correct_count,
  average_response_time = ss.avg_time
FROM session_stats ss
WHERE 
  gs.session_id = ss.session_id
  AND ss.attempt_count = ss.total_words
  AND (gs.completed = false OR gs.completed IS NULL);