/*
  # Clean up migrations and consolidate changes
  
  1. Purpose
    - Remove redundant migrations
    - Clean up obsolete code
    - Maintain only necessary database changes
    
  2. Changes
    - Remove duplicate column additions
    - Remove redundant trigger updates
    - Keep only the latest version of functions
*/

-- Drop obsolete functions and triggers first
DROP FUNCTION IF EXISTS validate_new_game_session();
DROP FUNCTION IF EXISTS validate_game_state(UUID, TEXT, TEXT, INTEGER);
DROP FUNCTION IF EXISTS check_session_completion();
DROP FUNCTION IF EXISTS analyze_error_pattern(text, text);
DROP FUNCTION IF EXISTS cleanup_old_sessions(uuid);
DROP FUNCTION IF EXISTS calculate_period_statistics(uuid, text, date);
DROP FUNCTION IF EXISTS calculate_all_time_statistics(uuid);

-- Drop obsolete triggers
DROP TRIGGER IF EXISTS validate_new_game_session_trigger ON game_sessions;
DROP TRIGGER IF EXISTS update_statistics_on_game_completion ON game_sessions;
DROP TRIGGER IF EXISTS check_session_completion_trigger ON word_attempts;
DROP TRIGGER IF EXISTS update_game_stats_trigger ON word_attempts;

-- Clean up duplicate columns
ALTER TABLE game_sessions
DROP COLUMN IF EXISTS session_average_response_time;

ALTER TABLE user_statistics
DROP COLUMN IF EXISTS statistics_average_response_time;

-- Keep only the essential trigger function
CREATE OR REPLACE FUNCTION public.update_session_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update game session statistics
  UPDATE public.game_sessions
  SET 
    correct_words = (
      SELECT COUNT(*) 
      FROM public.word_attempts 
      WHERE session_id = NEW.session_id AND is_correct = true
    ),
    average_response_time = (
      SELECT AVG(response_time_ms)::double precision
      FROM public.word_attempts
      WHERE session_id = NEW.session_id
    )
  WHERE session_id = NEW.session_id;
  
  -- Check if session should be completed
  IF (
    SELECT COUNT(*)
    FROM public.word_attempts
    WHERE session_id = NEW.session_id
  ) = (
    SELECT total_words
    FROM public.game_sessions
    WHERE session_id = NEW.session_id
  ) THEN
    UPDATE public.game_sessions
    SET 
      completed = true,
      end_time = COALESCE(end_time, NOW())
    WHERE session_id = NEW.session_id
    AND (completed = false OR completed IS NULL);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate only the essential trigger
DROP TRIGGER IF EXISTS update_session_stats_trigger ON word_attempts;
CREATE TRIGGER update_session_stats_trigger
  AFTER INSERT OR UPDATE ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_session_stats();