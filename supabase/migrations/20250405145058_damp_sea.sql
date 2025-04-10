/*
  # Remove statistics reset functionality
  
  1. Changes
    - Remove any remaining reset-related functionality
    - Clean up any temporary data
    - Ensure statistics continue to accumulate naturally
    
  2. Notes
    - This migration removes the statistics reset feature
    - No data will be lost
    - Statistics will continue to accumulate through normal gameplay
*/

-- Drop any remaining triggers
DROP TRIGGER IF EXISTS update_user_statistics ON game_sessions;

-- Clean up any temporary data
DELETE FROM user_statistics
WHERE total_time_spent = interval '0'
  AND updated_at > now() - interval '1 day';