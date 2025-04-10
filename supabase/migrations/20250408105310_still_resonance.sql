/*
  # Remove redundant response time column

  1. Changes
    - Remove redundant session_average_response_time column from game_sessions table
    - Keep average_response_time as the single source of truth
    
  2. Purpose
    - Fix ambiguous column reference error
    - Maintain data consistency
*/

-- Remove redundant column if it exists
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'game_sessions' 
    AND column_name = 'session_average_response_time'
  ) THEN
    ALTER TABLE game_sessions DROP COLUMN session_average_response_time;
  END IF;
END $$;