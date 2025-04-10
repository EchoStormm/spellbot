/*
  # Add trigger for updating user statistics

  1. New Functions
    - `calculate_user_daily_statistics`: Calculates daily statistics for a user
    - `update_user_statistics_trigger`: Trigger function that runs after game session updates

  2. Changes
    - Adds trigger on game_sessions table
    - Updates user_statistics automatically when a game session is completed

  3. Security
    - Functions execute with security definer to ensure proper access
*/

-- Function to calculate daily statistics
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
    SUM(total_words)::INTEGER as total_words_attempted,
    SUM(correct_words)::INTEGER as total_words_correct,
    AVG(average_response_time) as average_response_time,
    SUM(end_time - start_time)::INTERVAL as total_time_spent
  FROM game_sessions
  WHERE user_id = p_user_id
    AND DATE(created_at) = p_date
    AND completed = true;
END;
$$;

-- Trigger function to update user statistics
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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_user_statistics ON game_sessions;

-- Create trigger
CREATE TRIGGER update_user_statistics
  AFTER INSERT OR UPDATE
  ON game_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_user_statistics_trigger();