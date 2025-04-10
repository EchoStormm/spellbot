/*
  # Add period type enum and update statistics functions
  
  1. Changes
    - Add period_type enum for daily, weekly, monthly
    - Update statistics functions to handle different periods
    - Add indexes for better performance
    
  2. Purpose
    - Support different time period views in dashboard
    - Improve query performance
*/

-- Add index for period filtering
CREATE INDEX IF NOT EXISTS user_statistics_period_idx 
ON user_statistics(user_id, period_type, period_start);

-- Function to calculate statistics for a given period
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