/*
  # Remove all-time statistics functionality
  
  1. Changes
    - Drop all-time statistics function
    - Remove trigger that updates all-time stats
    - Clean up any related data
    
  2. Purpose
    - Remove unused statistics tracking
    - Simplify database schema
*/

-- Drop the trigger that uses all-time statistics
DROP TRIGGER IF EXISTS update_all_time_stats_trigger ON game_sessions;

-- Drop the function
DROP FUNCTION IF EXISTS calculate_all_time_statistics(uuid);

-- Remove any all-time statistics records
DELETE FROM user_statistics 
WHERE period_type = 'all-time';