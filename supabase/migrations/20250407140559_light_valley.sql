/*
  # Add detailed session logging

  1. Changes
    - Add logging for session creation
    - Add logging for session updates
    - Add logging for session completion
    - Add logging for word attempts
    
  2. Purpose
    - Improve debugging capabilities
    - Track session lifecycle
    - Monitor user progress
*/

-- Function to log session events with details
CREATE OR REPLACE FUNCTION log_session_event(
  p_session_id UUID,
  p_event_type TEXT,
  p_details JSONB DEFAULT '{}'::JSONB
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RAISE LOG 'Game Session Event: % | Session: % | Details: %',
    p_event_type,
    p_session_id,
    p_details;
END;
$$;

-- Enhanced session validation with logging
CREATE OR REPLACE FUNCTION validate_new_game_session()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  active_sessions INTEGER;
  session_details JSONB;
BEGIN
  -- Count active sessions for this user
  SELECT COUNT(*)
  INTO active_sessions
  FROM game_sessions
  WHERE 
    user_id = NEW.user_id
    AND (completed = false OR completed IS NULL);

  -- Create session details for logging
  session_details = jsonb_build_object(
    'user_id', NEW.user_id,
    'game_mode', NEW.game_mode,
    'language', NEW.language,
    'total_words', NEW.total_words,
    'active_sessions_found', active_sessions
  );

  -- Log session creation
  PERFORM log_session_event(
    NEW.session_id,
    'SESSION_CREATED',
    session_details
  );

  -- Complete any existing active sessions
  IF active_sessions > 0 THEN
    UPDATE game_sessions
    SET 
      completed = true,
      end_time = NOW()
    WHERE 
      user_id = NEW.user_id
      AND (completed = false OR completed IS NULL);

    -- Log completion of existing sessions
    PERFORM log_session_event(
      NEW.session_id,
      'EXISTING_SESSIONS_COMPLETED',
      jsonb_build_object(
        'sessions_completed', active_sessions
      )
    );
  END IF;

  -- Validate new session data
  IF NEW.total_words <= 0 THEN
    PERFORM log_session_event(
      NEW.session_id,
      'VALIDATION_ERROR',
      jsonb_build_object(
        'error', 'Invalid total_words',
        'value', NEW.total_words
      )
    );
    RAISE EXCEPTION 'Invalid total_words count: %', NEW.total_words;
  END IF;

  IF NEW.game_mode NOT IN ('custom', 'spaced-repetition') THEN
    PERFORM log_session_event(
      NEW.session_id,
      'VALIDATION_ERROR',
      jsonb_build_object(
        'error', 'Invalid game_mode',
        'value', NEW.game_mode
      )
    );
    RAISE EXCEPTION 'Invalid game mode: %', NEW.game_mode;
  END IF;

  IF NEW.language NOT IN ('en', 'fr', 'de') THEN
    PERFORM log_session_event(
      NEW.session_id,
      'VALIDATION_ERROR',
      jsonb_build_object(
        'error', 'Invalid language',
        'value', NEW.language
      )
    );
    RAISE EXCEPTION 'Invalid language: %', NEW.language;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log any errors but allow the session to be created
    PERFORM log_session_event(
      NEW.session_id,
      'VALIDATION_ERROR',
      jsonb_build_object(
        'error', SQLERRM,
        'details', session_details
      )
    );
    RETURN NEW;
END;
$$;

-- Enhanced session completion check with logging
CREATE OR REPLACE FUNCTION check_session_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_words INTEGER;
  v_attempt_count INTEGER;
  attempt_details JSONB;
BEGIN
  -- Get session info
  SELECT 
    gs.total_words,
    COUNT(wa.attempt_id)
  INTO 
    v_total_words,
    v_attempt_count
  FROM game_sessions gs
  LEFT JOIN word_attempts wa ON wa.session_id = NEW.session_id
  WHERE gs.session_id = NEW.session_id
  GROUP BY gs.total_words;

  -- Create attempt details for logging
  attempt_details = jsonb_build_object(
    'word_id', NEW.word_id,
    'is_correct', NEW.is_correct,
    'response_time_ms', NEW.response_time_ms,
    'attempt_count', v_attempt_count,
    'total_words', v_total_words
  );

  -- Log word attempt
  PERFORM log_session_event(
    NEW.session_id,
    'WORD_ATTEMPT',
    attempt_details
  );

  -- Check for session completion
  IF v_attempt_count = v_total_words THEN
    UPDATE game_sessions gs
    SET 
      completed = true,
      end_time = COALESCE(gs.end_time, NOW())
    WHERE 
      gs.session_id = NEW.session_id
      AND (gs.completed = false OR gs.completed IS NULL);

    -- Log session completion
    PERFORM log_session_event(
      NEW.session_id,
      'SESSION_COMPLETED',
      jsonb_build_object(
        'total_attempts', v_attempt_count,
        'completion_time', NOW()
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Enhanced game stats update with logging
CREATE OR REPLACE FUNCTION update_game_session_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  stats_details JSONB;
BEGIN
  -- Calculate new statistics
  WITH session_stats AS (
    SELECT 
      COUNT(*) FILTER (WHERE is_correct) as correct_count,
      AVG(response_time_ms) as avg_response_time
    FROM word_attempts
    WHERE session_id = NEW.session_id
  )
  SELECT jsonb_build_object(
    'correct_words', correct_count,
    'average_response_time', avg_response_time,
    'attempt_number', v_attempt_count
  )
  INTO stats_details
  FROM session_stats;

  -- Log stats update
  PERFORM log_session_event(
    NEW.session_id,
    'STATS_UPDATED',
    stats_details
  );

  -- Update game session
  UPDATE game_sessions gs
  SET 
    correct_words = (stats_details->>'correct_words')::INTEGER,
    average_response_time = (stats_details->>'average_response_time')::FLOAT
  WHERE gs.session_id = NEW.session_id;

  RETURN NEW;
END;
$$;