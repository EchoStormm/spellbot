/*
  # Fix ambiguous column reference in statistics calculation

  1. Changes
    - Explicitly specify table name for average_response_time column in calculate_user_daily_statistics function
    - Update trigger function to use the qualified column name

  2. Notes
    - No data migration needed
    - No schema changes, only function updates
*/

-- Update the statistics calculation function to use qualified column names
CREATE OR REPLACE FUNCTION calculate_user_daily_statistics(
  p_user_id UUID,
  p_date DATE
)
RETURNS TABLE (
  total_sessions INTEGER,
  total_words_attempted INTEGER,
  total_words_correct INTEGER,
  average_response_time DOUBLE PRECISION,
  total_time_spent INTERVAL
) 
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::INTEGER as total_sessions,
    SUM(game_sessions.total_words)::INTEGER as total_words_attempted,
    SUM(game_sessions.correct_words)::INTEGER as total_words_correct,
    AVG(game_sessions.average_response_time) as average_response_time,
    SUM(game_sessions.end_time - game_sessions.start_time)::INTERVAL as total_time_spent
  FROM game_sessions
  WHERE game_sessions.user_id = p_user_id
    AND DATE(game_sessions.created_at) = p_date
    AND game_sessions.completed = true;
END;
$$;

-- Update the trigger function to use qualified column names
CREATE OR REPLACE FUNCTION update_user_statistics_trigger()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
  stats RECORD;
BEGIN
  -- Only proceed if the game session is completed
  IF NEW.completed = true THEN
    -- Calculate daily statistics
    SELECT * FROM calculate_user_daily_statistics(NEW.user_id, DATE(NEW.created_at)) INTO stats;
    
    -- Update or insert daily statistics
    INSERT INTO user_statistics (
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
      DATE(NEW.created_at),
      'daily',
      stats.total_sessions,
      stats.total_words_attempted,
      stats.total_words_correct,
      stats.average_response_time,
      stats.total_time_spent
    )
    ON CONFLICT (user_id, period_start, period_type)
    DO UPDATE SET
      total_sessions = EXCLUDED.total_sessions,
      total_words_attempted = EXCLUDED.total_words_attempted,
      total_words_correct = EXCLUDED.total_words_correct,
      average_response_time = EXCLUDED.average_response_time,
      total_time_spent = EXCLUDED.total_time_spent,
      updated_at = now();
  END IF;
  
  RETURN NEW;
END;
$$;