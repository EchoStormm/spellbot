/*
  # Reset time spent statistics

  1. Purpose
    - Reset time spent statistics for all users to fix incorrect calculations
    - Recalculate time spent based on completed sessions only
    
  2. Changes
    - Update all user_statistics records to reset time spent
    - Trigger recalculation by updating game_sessions created_at
*/

-- Reset time spent for all users
UPDATE user_statistics
SET total_time_spent = interval '0';

-- Trigger recalculation by touching game sessions
UPDATE game_sessions
SET created_at = created_at
WHERE date_trunc('day', created_at) = date_trunc('day', now())
  AND completed = true;