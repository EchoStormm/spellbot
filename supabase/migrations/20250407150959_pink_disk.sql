/*
  # Remove active session verification

  1. Changes
    - Drop the trigger function that checks for active sessions
    - Drop any related triggers on the game_sessions table
    - Remove any constraints related to active session verification

  2. Security
    - No changes to RLS policies
    - Existing security measures remain intact
*/

-- Drop the trigger function if it exists
DROP FUNCTION IF EXISTS check_active_session();

-- Drop any triggers that might be using the function
DROP TRIGGER IF EXISTS check_active_session_trigger ON game_sessions;

-- Remove any session verification constraints
ALTER TABLE game_sessions DROP CONSTRAINT IF EXISTS check_active_session;