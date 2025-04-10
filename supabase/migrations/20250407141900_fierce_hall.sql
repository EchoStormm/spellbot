/*
  # Fix duplicate game sessions issue

  1. Changes
    - Add session uniqueness constraint
    - Enhance session validation function
    - Add cleanup for existing duplicate sessions
    
  2. Purpose
    - Prevent multiple active sessions per user
    - Ensure clean session state transitions
    - Fix any existing duplicate sessions
*/

-- Function to validate new game sessions with enhanced duplicate prevention
CREATE OR REPLACE FUNCTION validate_new_game_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  active_session_id UUID;
  active_session_time TIMESTAMPTZ;
BEGIN
  -- Check for existing active session
  SELECT session_id, created_at
  INTO active_session_id, active_session_time
  FROM game_sessions
  WHERE user_id = NEW.user_id
    AND (completed = false OR completed IS NULL)
    AND created_at > NOW() - INTERVAL '5 minutes'
  ORDER BY created_at DESC
  LIMIT 1;

  -- If there's a very recent active session, prevent creating a new one
  IF active_session_id IS NOT NULL AND active_session_time > NOW() - INTERVAL '10 seconds' THEN
    RAISE EXCEPTION 'Active session exists: %. Please wait before starting a new session.', active_session_id;
  END IF;

  -- Complete any existing active sessions
  UPDATE game_sessions
  SET 
    completed = true,
    end_time = NOW()
  WHERE user_id = NEW.user_id
    AND (completed = false OR completed IS NULL)
    AND session_id != COALESCE(active_session_id, NULL);

  -- Validate session data
  IF NEW.total_words <= 0 THEN
    RAISE EXCEPTION 'Invalid total_words count: %', NEW.total_words;
  END IF;

  IF NEW.game_mode NOT IN ('custom', 'spaced-repetition') THEN
    RAISE EXCEPTION 'Invalid game mode: %', NEW.game_mode;
  END IF;

  IF NEW.language NOT IN ('en', 'fr', 'de') THEN
    RAISE EXCEPTION 'Invalid language: %', NEW.language;
  END IF;

  RETURN NEW;
END;
$$;

-- Drop existing trigger
DROP TRIGGER IF EXISTS validate_new_game_session_trigger ON game_sessions;

-- Recreate trigger
CREATE TRIGGER validate_new_game_session_trigger
  BEFORE INSERT ON game_sessions
  FOR EACH ROW
  EXECUTE FUNCTION validate_new_game_session();

-- Clean up any existing duplicate active sessions
WITH ranked_sessions AS (
  SELECT 
    session_id,
    user_id,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY user_id 
      ORDER BY created_at DESC
    ) as rn
  FROM game_sessions
  WHERE completed = false OR completed IS NULL
)
UPDATE game_sessions
SET 
  completed = true,
  end_time = NOW()
FROM ranked_sessions rs
WHERE game_sessions.session_id = rs.session_id
  AND rs.rn > 1;