/*
  # Fix function parameter naming and remove error analysis

  1. Changes
    - Drop existing cleanup_old_sessions function to avoid parameter name conflict
    - Drop analyze_error_pattern function that causes stack depth issues
    - Recreate cleanup_old_sessions function with consistent parameter name
    
  2. Purpose
    - Fix parameter naming conflict
    - Remove problematic error analysis function
    - Maintain session cleanup functionality
*/

-- Drop existing functions
DROP FUNCTION IF EXISTS cleanup_old_sessions(uuid);
DROP FUNCTION IF EXISTS analyze_error_pattern(text, text);

-- Recreate cleanup function with consistent parameter name
CREATE OR REPLACE FUNCTION cleanup_old_sessions(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete all sessions except the 10 most recent ones
  DELETE FROM game_sessions
  WHERE session_id IN (
    SELECT session_id
    FROM game_sessions
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    OFFSET 10
  );
END;
$$;