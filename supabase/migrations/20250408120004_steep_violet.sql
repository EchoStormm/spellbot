/*
  # Fix column names for response time tracking

  1. Changes
    - Add statistics_average_response_time column to user_statistics
    - Drop existing functions that reference the old column name
    - Recreate functions with correct column names
    
  2. Purpose
    - Fix column name mismatch
    - Maintain data integrity
    - Improve code clarity
*/

-- Drop existing functions first
DROP FUNCTION IF EXISTS calculate_period_statistics(uuid, text, date);
DROP FUNCTION IF EXISTS calculate_all_time_statistics(uuid);

-- Add new column with correct name if it doesn't exist
ALTER TABLE user_statistics
ADD COLUMN IF NOT EXISTS statistics_average_response_time double precision DEFAULT 0;

-- Function to calculate period statistics with correct column name
CREATE OR REPLACE FUNCTION calculate_period_statistics(
  p_user_id UUID,
  p_period_type TEXT,
  p_start_date DATE
)
RETURNS TABLE (
  total_sessions INTEGER,
  total_words_attempted INTEGER,
  total_words_correct INTEGER,
  statistics_average_response_time DOUBLE PRECISION,
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
    COALESCE(AVG(gs.statistics_average_response_time), 0)::DOUBLE PRECISION as statistics_average_response_time,
    COALESCE(SUM(gs.total_time_spent), interval '0')::INTERVAL as total_time_spent
  FROM user_statistics gs
  WHERE gs.user_id = p_user_id
    AND gs.period_type = p_period_type
    AND gs.period_start = p_start_date;
END;
$$;

-- Function to calculate all-time statistics with correct column name
CREATE OR REPLACE FUNCTION calculate_all_time_statistics(
  p_user_id UUID
)
RETURNS TABLE (
  total_sessions INTEGER,
  total_words_attempted INTEGER,
  total_words_correct INTEGER,
  statistics_average_response_time DOUBLE PRECISION,
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
    AVG(average_response_time) as statistics_average_response_time,
    SUM(end_time - start_time)::INTERVAL as total_time_spent
  FROM game_sessions
  WHERE user_id = p_user_id
    AND completed = true;
END;
$$;