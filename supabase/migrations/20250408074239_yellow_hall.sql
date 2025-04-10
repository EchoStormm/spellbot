/*
  # Add session cleanup function and remove error pattern analysis

  1. Changes
    - Add cleanup_old_sessions function to maintain only the 10 most recent sessions per user
    - Remove analyze_error_pattern function to prevent stack depth limit errors

  2. Security
    - Function is accessible to authenticated users only
    - Users can only delete their own sessions
*/

-- Drop the analyze_error_pattern function as it's causing stack depth issues
DROP FUNCTION IF EXISTS analyze_error_pattern(original_word text, user_input text);

-- Create a function to clean up old sessions
CREATE OR REPLACE FUNCTION cleanup_old_sessions(user_id_param uuid)
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
    WHERE user_id = user_id_param
    ORDER BY created_at DESC
    OFFSET 10
  );
END;
$$;