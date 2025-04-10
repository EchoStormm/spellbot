/*
  # Remove time spent statistics reset

  1. Changes
    - Drop the redundant trigger that was causing issues
    - Remove the time spent reset functionality
    - Clean up any remaining temporary data
    
  2. Notes
    - This migration undoes the previous time spent reset
    - Statistics will now accumulate naturally through the game sessions
*/

-- Drop the redundant trigger if it exists
DROP TRIGGER IF EXISTS update_user_statistics ON game_sessions;

-- Remove any temporary data or flags related to time reset
DELETE FROM user_statistics
WHERE total_time_spent = interval '0'
  AND updated_at > now() - interval '1 day';

-- Recalculate statistics for today's completed sessions
WITH daily_stats AS (
  SELECT 
    user_id,
    COUNT(*) as sessions,
    SUM(end_time - start_time) as total_time,
    AVG(average_response_time) as avg_response_time,
    SUM(correct_words) as correct_words,
    SUM(total_words) as total_words
  FROM game_sessions
  WHERE date_trunc('day', created_at) = date_trunc('day', now())
    AND completed = true
  GROUP BY user_id
)
UPDATE user_statistics us
SET 
  total_sessions = ds.sessions,
  total_time_spent = ds.total_time,
  average_response_time = ds.avg_response_time,
  total_words_correct = ds.correct_words,
  total_words_attempted = ds.total_words
FROM daily_stats ds
WHERE us.user_id = ds.user_id
  AND us.period_type = 'daily'
  AND us.period_start = date_trunc('day', now());