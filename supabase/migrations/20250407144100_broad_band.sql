/*
  # Fix game session initialization and handling

  1. Changes
    - Add function to properly handle session initialization
    - Add validation for game state
    - Improve session cleanup
    - Add better error handling
    
  2. Purpose
    - Fix blank page issues
    - Ensure proper session initialization
    - Prevent session conflicts
*/

-- Function to validate game state
CREATE OR REPLACE FUNCTION validate_game_state(
  p_user_id UUID,
  p_game_mode TEXT,
  p_language TEXT,
  p_total_words INTEGER
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session_id UUID;
BEGIN
  -- Validate input parameters
  IF p_total_words <= 0 THEN
    RAISE EXCEPTION 'Invalid word count: %', p_total_words;
  END IF;

  IF p_game_mode NOT IN ('custom', 'spaced-repetition') THEN
    RAISE EXCEPTION 'Invalid game mode: %', p_game_mode;
  END IF;

  IF p_language NOT IN ('en', 'fr', 'de') THEN
    RAISE EXCEPTION 'Invalid language: %', p_language;
  END IF;

  -- Check for existing active session
  SELECT session_id INTO v_session_id
  FROM game_sessions
  WHERE user_id = p_user_id
    AND (completed = false OR completed IS NULL)
    AND created_at > NOW() - INTERVAL '5 minutes'
  ORDER BY created_at DESC
  LIMIT 1;

  -- If recent active session exists, return its ID
  IF v_session_id IS NOT NULL THEN
    RETURN v_session_id;
  END IF;

  -- Complete any old sessions
  UPDATE game_sessions
  SET 
    completed = true,
    end_time = NOW()
  WHERE user_id = p_user_id
    AND (completed = false OR completed IS NULL);

  -- Create new session
  INSERT INTO game_sessions (
    user_id,
    game_mode,
    language,
    total_words,
    start_time
  ) VALUES (
    p_user_id,
    p_game_mode,
    p_language,
    p_total_words,
    NOW()
  ) RETURNING session_id INTO v_session_id;

  RETURN v_session_id;
END;
$$;

-- Function to validate new game sessions
CREATE OR REPLACE FUNCTION validate_new_game_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_session_id UUID;
BEGIN
  -- Check for existing active session
  SELECT session_id INTO v_session_id
  FROM game_sessions
  WHERE user_id = NEW.user_id
    AND (completed = false OR completed IS NULL)
    AND created_at > NOW() - INTERVAL '5 minutes'
    AND session_id != NEW.session_id
  ORDER BY created_at DESC
  LIMIT 1;

  -- If there's a recent active session, prevent creating a new one
  IF v_session_id IS NOT NULL THEN
    RAISE EXCEPTION 'Active session exists: %. Please wait before starting a new session.', v_session_id;
  END IF;

  -- Complete any old sessions
  UPDATE game_sessions
  SET 
    completed = true,
    end_time = NOW()
  WHERE user_id = NEW.user_id
    AND (completed = false OR completed IS NULL)
    AND session_id != NEW.session_id;

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

-- Clean up any existing problematic sessions
UPDATE game_sessions
SET 
  completed = true,
  end_time = NOW()
WHERE 
  (completed = false OR completed IS NULL)
  AND created_at < NOW() - INTERVAL '5 minutes';