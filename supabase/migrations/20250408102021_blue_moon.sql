/*
  # Fix ambiguous column reference in game session updates

  1. Changes
    - Update trigger functions to use qualified column names
    - Fix ambiguous column references in statistics calculations
    - Improve error handling in triggers
    
  2. Purpose
    - Fix "column reference average_response_time is ambiguous" error
    - Ensure proper statistics updates
    - Maintain data consistency
*/

-- Drop existing triggers first
DROP TRIGGER IF EXISTS update_session_stats_trigger ON word_attempts;
DROP TRIGGER IF EXISTS handle_session_completion_trigger ON game_sessions;

-- Update the session stats function with qualified column names
CREATE OR REPLACE FUNCTION update_session_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_attempts INTEGER;
  v_correct_count INTEGER;
  v_avg_response_time FLOAT;
BEGIN
  -- Calculate statistics with explicit table references
  SELECT 
    COUNT(*),
    COUNT(*) FILTER (WHERE wa.is_correct),
    AVG(wa.response_time_ms)
  INTO 
    v_total_attempts,
    v_correct_count,
    v_avg_response_time
  FROM word_attempts wa
  WHERE wa.session_id = NEW.session_id;

  -- Update game session with new statistics
  UPDATE game_sessions gs
  SET 
    correct_words = v_correct_count,
    average_response_time = v_avg_response_time
  WHERE gs.session_id = NEW.session_id;

  -- Check if session should be completed
  IF v_total_attempts = (
    SELECT gs.total_words 
    FROM game_sessions gs 
    WHERE gs.session_id = NEW.session_id
  ) THEN
    UPDATE game_sessions gs
    SET 
      completed = true,
      end_time = COALESCE(gs.end_time, NOW())
    WHERE gs.session_id = NEW.session_id
    AND (gs.completed = false OR gs.completed IS NULL);
  END IF;

  RETURN NEW;
END;
$$;

-- Recreate the trigger
CREATE TRIGGER update_session_stats_trigger
  AFTER INSERT OR UPDATE ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_session_stats();

-- Function to handle session completion
CREATE OR REPLACE FUNCTION handle_session_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_correct_count INTEGER;
  v_avg_response_time FLOAT;
BEGIN
  -- Only proceed if the session is being marked as complete
  IF NEW.completed = true AND (OLD.completed = false OR OLD.completed IS NULL) THEN
    -- Calculate final statistics with explicit table references
    SELECT 
      COUNT(*) FILTER (WHERE wa.is_correct),
      AVG(wa.response_time_ms)
    INTO 
      v_correct_count,
      v_avg_response_time
    FROM word_attempts wa
    WHERE wa.session_id = NEW.session_id;

    -- Update the session with final statistics
    UPDATE game_sessions gs
    SET 
      correct_words = v_correct_count,
      average_response_time = v_avg_response_time,
      end_time = COALESCE(gs.end_time, NOW())
    WHERE gs.session_id = NEW.session_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Recreate the completion trigger
CREATE TRIGGER handle_session_completion_trigger
  AFTER UPDATE ON game_sessions
  FOR EACH ROW
  EXECUTE FUNCTION handle_session_completion();