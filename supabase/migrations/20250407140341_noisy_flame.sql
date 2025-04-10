/*
  # Improve session validation and error handling

  1. Changes
    - Add error logging for session validation
    - Add constraints to prevent invalid session states
    - Add function to recover from invalid states
    
  2. Security
    - Maintain existing RLS policies
    - Keep SECURITY DEFINER for admin operations
*/

-- Add session state validation
CREATE OR REPLACE FUNCTION validate_new_game_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  active_sessions INTEGER;
BEGIN
  -- Count active sessions for this user
  SELECT COUNT(*)
  INTO active_sessions
  FROM game_sessions
  WHERE 
    user_id = NEW.user_id
    AND (completed = false OR completed IS NULL);

  -- Log if we find multiple active sessions
  IF active_sessions > 0 THEN
    RAISE LOG 'Found % active sessions for user %. Auto-completing them.', 
      active_sessions, NEW.user_id;
  END IF;

  -- Complete any existing active sessions
  UPDATE game_sessions
  SET 
    completed = true,
    end_time = NOW()
  WHERE 
    user_id = NEW.user_id
    AND (completed = false OR completed IS NULL);

  -- Validate new session data
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
EXCEPTION
  WHEN OTHERS THEN
    -- Log any errors but allow the session to be created
    RAISE LOG 'Error in validate_new_game_session: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Add constraints to game_sessions table
ALTER TABLE game_sessions
  ADD CONSTRAINT check_total_words 
    CHECK (total_words > 0),
  ADD CONSTRAINT check_game_mode 
    CHECK (game_mode IN ('custom', 'spaced-repetition')),
  ADD CONSTRAINT check_language 
    CHECK (language IN ('en', 'fr', 'de'));

-- Function to fix invalid session states
CREATE OR REPLACE FUNCTION fix_invalid_session_states()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Complete sessions that have all attempts but aren't marked complete
  UPDATE game_sessions gs
  SET 
    completed = true,
    end_time = COALESCE(gs.end_time, NOW())
  WHERE 
    (gs.completed = false OR gs.completed IS NULL)
    AND (
      SELECT COUNT(*)
      FROM word_attempts wa
      WHERE wa.session_id = gs.session_id
    ) = gs.total_words;

  -- Complete very old sessions
  UPDATE game_sessions
  SET 
    completed = true,
    end_time = COALESCE(end_time, NOW())
  WHERE 
    (completed = false OR completed IS NULL)
    AND created_at < NOW() - INTERVAL '1 hour';

  -- Log summary of fixes
  RAISE LOG 'Fixed invalid session states';
END;
$$;