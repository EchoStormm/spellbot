/*
  # Fix statistics column names and update related functions
  
  1. Changes
    - Add average_response_time column to game_sessions
    - Update functions to use correct column names
    - Fix column references in triggers
    
  2. Purpose
    - Fix ambiguous column references
    - Ensure consistent column naming
    - Maintain data integrity
*/

-- Add average_response_time column to game_sessions if it doesn't exist
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'game_sessions' 
    AND column_name = 'average_response_time'
  ) THEN
    ALTER TABLE game_sessions
    ADD COLUMN average_response_time double precision DEFAULT 0;
  END IF;
END $$;

-- Update session stats function to use correct column names
CREATE OR REPLACE FUNCTION update_session_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_attempts INTEGER;
  v_correct_count INTEGER;
  v_avg_response_time FLOAT;
BEGIN
  -- Calculate statistics with explicit table references
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE wa.is_correct),
    AVG(wa.response_time_ms)
  INTO 
    v_total_attempts,
    v_correct_count,
    v_avg_response_time
  FROM word_attempts wa
  WHERE wa.session_id = NEW.session_id;

  -- Update game session with new statistics
  UPDATE game_sessions gs
  SET 
    correct_words = v_correct_count,
    average_response_time = v_avg_response_time
  WHERE gs.session_id = NEW.session_id;

  -- Check if session should be completed
  IF v_total_attempts = (
    SELECT gs.total_words 
    FROM game_sessions gs 
    WHERE gs.session_id = NEW.session_id
  ) THEN
    UPDATE game_sessions gs
    SET 
      completed = true,
      end_time = COALESCE(gs.end_time, NOW())
    WHERE gs.session_id = NEW.session_id
    AND (gs.completed = false OR gs.completed IS NULL);
  END IF;

  RETURN NEW;
END;
$$;

-- Update session completion function
CREATE OR REPLACE FUNCTION handle_session_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_correct_count INTEGER;
  v_avg_response_time FLOAT;
BEGIN
  -- Only proceed if the session is being marked as complete
  IF NEW.completed = true AND (OLD.completed = false OR OLD.completed IS NULL) THEN
    -- Calculate final statistics with explicit table references
    SELECT 
      COUNT(*) FILTER (WHERE wa.is_correct),
      AVG(wa.response_time_ms)
    INTO 
      v_correct_count,
      v_avg_response_time
    FROM word_attempts wa
    WHERE wa.session_id = NEW.session_id;

    -- Update the session with final statistics
    UPDATE game_sessions gs
    SET 
      correct_words = v_correct_count,
      average_response_time = v_avg_response_time,
      end_time = COALESCE(gs.end_time, NOW())
    WHERE gs.session_id = NEW.session_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Update all-time statistics function
CREATE OR REPLACE FUNCTION calculate_all_time_statistics(
  p_user_id UUID
)
RETURNS TABLE (
  total_sessions INTEGER,
  total_words_attempted INTEGER,
  total_words_correct INTEGER,
  average_response_time DOUBLE PRECISION,
  total_time_spent INTERVAL
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::INTEGER as total_sessions,
    SUM(total_words)::INTEGER as total_words_attempted,
    SUM(correct_words)::INTEGER as total_words_correct,
    AVG(average_response_time) as average_response_time,
    SUM(end_time - start_time)::INTERVAL as total_time_spent
  FROM game_sessions
  WHERE user_id = p_user_id
    AND completed = true;
END;
$$;

-- Update period statistics function
CREATE OR REPLACE FUNCTION calculate_period_statistics(
  p_user_id UUID,
  p_period_type TEXT,
  p_start_date DATE
)
RETURNS TABLE (
  total_sessions INTEGER,
  total_words_attempted INTEGER,
  total_words_correct INTEGER,
  average_response_time DOUBLE PRECISION,
  total_time_spent INTERVAL
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(SUM(gs.total_sessions), 0)::INTEGER as total_sessions,
    COALESCE(SUM(gs.total_words_attempted), 0)::INTEGER as total_words_attempted,
    COALESCE(SUM(gs.total_words_correct), 0)::INTEGER as total_words_correct,
    COALESCE(AVG(gs.average_response_time), 0)::DOUBLE PRECISION as average_response_time,
    COALESCE(SUM(gs.total_time_spent), interval '0')::INTERVAL as total_time_spent
  FROM user_statistics gs
  WHERE gs.user_id = p_user_id
    AND gs.period_type = p_period_type
    AND gs.period_start = p_start_date;
END;
$$;

-- Ensure RLS policies continue to apply
ALTER TABLE game_sessions ENABLE ROW LEVEL SECURITY;