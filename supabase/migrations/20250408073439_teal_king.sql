/*
  # Rebuild Game Sessions System
  
  1. Changes
    - Add function to maintain 10 most recent sessions per user
    - Add trigger to automatically clean up old sessions
    - Update session handling logic
    
  2. Purpose
    - Improve performance by limiting stored sessions
    - Maintain only relevant game history
    - Ensure consistent session cleanup
*/

-- First, clean up existing triggers
DROP TRIGGER IF EXISTS validate_new_game_session_trigger ON game_sessions;
DROP TRIGGER IF EXISTS update_statistics_on_game_completion ON game_sessions;
DROP TRIGGER IF EXISTS check_session_completion_trigger ON word_attempts;
DROP TRIGGER IF EXISTS update_game_stats_trigger ON word_attempts;

-- Drop existing functions
DROP FUNCTION IF EXISTS validate_new_game_session();
DROP FUNCTION IF EXISTS validate_game_state(UUID, TEXT, TEXT, INTEGER);
DROP FUNCTION IF EXISTS check_session_completion();
DROP FUNCTION IF EXISTS update_game_session_stats();

-- Function to clean up old sessions
CREATE OR REPLACE FUNCTION cleanup_old_sessions(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  old_session_ids UUID[];
BEGIN
  -- Get session IDs to remove (keep only 10 most recent)
  SELECT ARRAY_AGG(session_id)
  INTO old_session_ids
  FROM (
    SELECT session_id
    FROM game_sessions
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    OFFSET 10
  ) old_sessions;

  -- Delete word attempts for old sessions
  IF old_session_ids IS NOT NULL THEN
    DELETE FROM word_attempts
    WHERE session_id = ANY(old_session_ids);

    -- Delete old sessions
    DELETE FROM game_sessions
    WHERE session_id = ANY(old_session_ids);
  END IF;
END;
$$;

-- Function to handle session completion
CREATE OR REPLACE FUNCTION handle_session_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update session statistics
  WITH session_stats AS (
    SELECT 
      COUNT(*) FILTER (WHERE is_correct) as correct_count,
      AVG(response_time_ms) as avg_response_time
    FROM word_attempts
    WHERE session_id = NEW.session_id
  )
  UPDATE game_sessions
  SET 
    correct_words = session_stats.correct_count,
    average_response_time = session_stats.avg_response_time,
    completed = true,
    end_time = NOW()
  FROM session_stats
  WHERE session_id = NEW.session_id
  AND (
    SELECT COUNT(*)
    FROM word_attempts
    WHERE session_id = NEW.session_id
  ) = total_words;

  -- Clean up old sessions when a new one completes
  IF NEW.completed AND NOT OLD.completed THEN
    PERFORM cleanup_old_sessions(NEW.user_id);
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for session completion
CREATE TRIGGER handle_session_completion_trigger
  AFTER UPDATE ON game_sessions
  FOR EACH ROW
  EXECUTE FUNCTION handle_session_completion();

-- Function to update session stats
CREATE OR REPLACE FUNCTION update_session_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update session statistics
  WITH session_stats AS (
    SELECT 
      COUNT(*) FILTER (WHERE is_correct) as correct_count,
      AVG(response_time_ms) as avg_response_time
    FROM word_attempts
    WHERE session_id = NEW.session_id
  )
  UPDATE game_sessions
  SET 
    correct_words = session_stats.correct_count,
    average_response_time = session_stats.avg_response_time
  FROM session_stats
  WHERE session_id = NEW.session_id;

  -- Check if session is complete
  UPDATE game_sessions
  SET 
    completed = true,
    end_time = NOW()
  WHERE session_id = NEW.session_id
  AND (
    SELECT COUNT(*)
    FROM word_attempts
    WHERE session_id = NEW.session_id
  ) = total_words
  AND (completed = false OR completed IS NULL);

  RETURN NEW;
END;
$$;

-- Create trigger for updating session stats
CREATE TRIGGER update_session_stats_trigger
  AFTER INSERT OR UPDATE ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_session_stats();

-- Clean up existing sessions to keep only 10 most recent per user
DO $$
DECLARE
  user_record RECORD;
BEGIN
  FOR user_record IN 
    SELECT DISTINCT user_id 
    FROM game_sessions
  LOOP
    PERFORM cleanup_old_sessions(user_record.user_id);
  END LOOP;
END;
$$;