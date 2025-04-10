/*
  # Fix foreign key constraint violation in session cleanup

  1. Changes
    - Update cleanup_old_sessions function to delete word_attempts first
    - Add ON DELETE CASCADE to foreign key constraint
    - Add proper error handling
    
  2. Purpose
    - Fix "Key is still referenced" error
    - Ensure proper cleanup of related records
    - Maintain data integrity
*/

-- Drop existing function
DROP FUNCTION IF EXISTS cleanup_old_sessions(uuid);

-- Recreate cleanup function with proper cascade
CREATE OR REPLACE FUNCTION cleanup_old_sessions(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_old_session_ids uuid[];
BEGIN
  -- Get session IDs to remove (keep only 10 most recent)
  SELECT ARRAY_AGG(session_id)
  INTO v_old_session_ids
  FROM (
    SELECT session_id
    FROM game_sessions
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    OFFSET 10
  ) old_sessions;

  -- Only proceed if there are sessions to clean up
  IF v_old_session_ids IS NOT NULL THEN
    -- First, delete word attempts for old sessions
    DELETE FROM word_attempts
    WHERE session_id = ANY(v_old_session_ids);

    -- Then delete the old sessions
    DELETE FROM game_sessions
    WHERE session_id = ANY(v_old_session_ids);
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't throw it to prevent disrupting the application
    RAISE LOG 'Error in cleanup_old_sessions: %', SQLERRM;
END;
$$;

-- Drop existing foreign key constraint
ALTER TABLE word_attempts
DROP CONSTRAINT IF EXISTS word_attempts_session_id_fkey;

-- Recreate foreign key with CASCADE
ALTER TABLE word_attempts
ADD CONSTRAINT word_attempts_session_id_fkey
FOREIGN KEY (session_id)
REFERENCES game_sessions(session_id)
ON DELETE CASCADE;