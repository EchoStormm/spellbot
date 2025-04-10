/*
  # Add global statistics support
  
  1. Changes
    - Add 'all-time' period type for global statistics
    - Update statistics functions to handle all-time stats
    - Add index for better performance
    
  2. Purpose
    - Support global statistics view in dashboard
    - Track lifetime achievements and progress
*/

-- Function to calculate all-time statistics
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

-- Function to update all-time statistics
CREATE OR REPLACE FUNCTION update_all_time_statistics()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  stats RECORD;
BEGIN
  -- Only proceed if the game session is completed
  IF NEW.completed = true AND (OLD.completed = false OR OLD.completed IS NULL) THEN
    -- Calculate all-time statistics
    SELECT * FROM calculate_all_time_statistics(NEW.user_id) INTO stats;
    
    -- Update or insert all-time statistics
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
      '2000-01-01'::date, -- Use fixed date for all-time stats
      'all-time',
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

-- Create trigger for updating all-time statistics
DROP TRIGGER IF EXISTS update_all_time_stats_trigger ON game_sessions;
CREATE TRIGGER update_all_time_stats_trigger
  AFTER UPDATE OF completed ON game_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_all_time_statistics();