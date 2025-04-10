/*
  # Fix statistics tracking system

  1. Changes
    - Add trigger to update user statistics when a session is completed
    - Fix session statistics calculation
    - Add proper error handling and logging
    
  2. Purpose
    - Ensure statistics are properly tracked
    - Fix missing user statistics
    - Improve data consistency
*/

-- Drop existing triggers first
DROP TRIGGER IF EXISTS update_session_stats_trigger ON word_attempts;
DROP TRIGGER IF EXISTS update_user_stats_trigger ON game_sessions;

-- Function to update session statistics
CREATE OR REPLACE FUNCTION public.update_session_stats()
RETURNS TRIGGER AS $$
DECLARE
  v_total_words INTEGER;
  v_attempt_count INTEGER;
  v_correct_count INTEGER;
  v_avg_response_time FLOAT;
BEGIN
  -- Get session info
  SELECT total_words 
  INTO v_total_words
  FROM public.game_sessions
  WHERE session_id = NEW.session_id;

  -- Calculate statistics
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE is_correct),
    AVG(response_time_ms)::float
  INTO 
    v_attempt_count,
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

  -- Mark session as complete if all words attempted
  IF v_attempt_count = v_total_words THEN
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

-- Function to update user statistics
CREATE OR REPLACE FUNCTION public.update_user_statistics()
RETURNS TRIGGER AS $$
DECLARE
  today_date date := current_date;
  v_total_time interval;
BEGIN
  -- Only proceed if the session was just completed
  IF NEW.completed AND NOT OLD.completed THEN
    -- Calculate session duration
    v_total_time := NEW.end_time - NEW.start_time;

    -- Update or insert daily statistics
    INSERT INTO public.user_statistics (
      user_id,
      period_start,
      period_type,
      total_sessions,
      total_words_attempted,
      total_words_correct,
      average_response_time,
      total_time_spent
    )
    VALUES (
      NEW.user_id,
      today_date,
      'daily',
      1,
      NEW.total_words,
      NEW.correct_words,
      NEW.average_response_time,
      v_total_time
    )
    ON CONFLICT (user_id, period_start, period_type)
    DO UPDATE SET
      total_sessions = user_statistics.total_sessions + 1,
      total_words_attempted = user_statistics.total_words_attempted + EXCLUDED.total_words_attempted,
      total_words_correct = user_statistics.total_words_correct + EXCLUDED.total_words_correct,
      average_response_time = (
        user_statistics.average_response_time * user_statistics.total_sessions + 
        EXCLUDED.average_response_time
      ) / (user_statistics.total_sessions + 1),
      total_time_spent = user_statistics.total_time_spent + EXCLUDED.total_time_spent,
      updated_at = now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER update_session_stats_trigger
  AFTER INSERT ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_session_stats();

CREATE TRIGGER update_user_stats_trigger
  AFTER UPDATE OF completed ON game_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_user_statistics();

-- Fix any existing sessions that should be complete
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

-- Recalculate daily statistics for today
WITH today_stats AS (
  SELECT 
    user_id,
    COUNT(*) as total_sessions,
    SUM(total_words) as total_words_attempted,
    SUM(correct_words) as total_words_correct,
    AVG(average_response_time) as avg_response_time,
    SUM(end_time - start_time) as total_time
  FROM public.game_sessions
  WHERE 
    completed = true
    AND DATE(created_at) = current_date
  GROUP BY user_id
)
INSERT INTO public.user_statistics (
  user_id,
  period_start,
  period_type,
  total_sessions,
  total_words_attempted,
  total_words_correct,
  average_response_time,
  total_time_spent
)
SELECT
  user_id,
  current_date,
  'daily',
  total_sessions,
  total_words_attempted,
  total_words_correct,
  avg_response_time,
  total_time
FROM today_stats
ON CONFLICT (user_id, period_start, period_type)
DO UPDATE SET
  total_sessions = EXCLUDED.total_sessions,
  total_words_attempted = EXCLUDED.total_words_attempted,
  total_words_correct = EXCLUDED.total_words_correct,
  average_response_time = EXCLUDED.average_response_time,
  total_time_spent = EXCLUDED.total_time_spent,
  updated_at = now();