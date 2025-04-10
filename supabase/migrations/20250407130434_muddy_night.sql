/*
  # Fix game session tracking and completion

  1. Changes
    - Add explicit completion check trigger
    - Fix statistics calculation
    - Add cleanup for incomplete sessions
    - Add session status tracking
    - Add proper error handling

  2. Security
    - Maintain existing RLS policies
    - Keep SECURITY DEFINER for admin functions
*/

-- Drop existing triggers first to avoid conflicts
DROP TRIGGER IF EXISTS update_game_stats_trigger ON word_attempts;
DROP TRIGGER IF EXISTS check_session_completion_trigger ON word_attempts;

-- Function to update game session statistics with proper error handling
CREATE OR REPLACE FUNCTION update_game_session_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update game session statistics with explicit table references
  UPDATE game_sessions gs
  SET 
    correct_words = (
      SELECT COUNT(*) 
      FROM word_attempts wa
      WHERE wa.session_id = NEW.session_id 
      AND wa.is_correct = true
    ),
    average_response_time = (
      SELECT AVG(wa.response_time_ms)
      FROM word_attempts wa
      WHERE wa.session_id = NEW.session_id
    )
  WHERE gs.session_id = NEW.session_id;

  -- Handle any errors
  IF NOT FOUND THEN
    RAISE WARNING 'Game session not found: %', NEW.session_id;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error updating game session stats: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Function to check session completion with proper validation
CREATE OR REPLACE FUNCTION check_session_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_words INTEGER;
  v_attempt_count INTEGER;
BEGIN
  -- Get the total words for this session
  SELECT gs.total_words 
  INTO v_total_words
  FROM game_sessions gs
  WHERE gs.session_id = NEW.session_id;

  IF v_total_words IS NULL THEN
    RAISE WARNING 'Game session not found: %', NEW.session_id;
    RETURN NEW;
  END IF;

  -- Count attempts for this session
  SELECT COUNT(*)
  INTO v_attempt_count
  FROM word_attempts wa
  WHERE wa.session_id = NEW.session_id;

  -- Mark session as complete if all words attempted
  IF v_attempt_count = v_total_words THEN
    UPDATE game_sessions gs
    SET 
      completed = true,
      end_time = COALESCE(gs.end_time, NOW())
    WHERE gs.session_id = NEW.session_id
    AND (gs.completed = false OR gs.completed IS NULL);
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error checking session completion: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Recreate triggers with proper ordering
CREATE TRIGGER update_game_stats_trigger
  AFTER INSERT OR UPDATE ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_game_session_stats();

CREATE TRIGGER check_session_completion_trigger
  AFTER INSERT ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION check_session_completion();

-- Fix any existing incomplete sessions that should be complete
WITH session_stats AS (
  SELECT 
    wa.session_id,
    COUNT(*) as attempt_count,
    gs.total_words
  FROM word_attempts wa
  JOIN game_sessions gs ON wa.session_id = gs.session_id
  WHERE gs.completed = false OR gs.completed IS NULL
  GROUP BY wa.session_id, gs.total_words
  HAVING COUNT(*) = gs.total_words
)
UPDATE game_sessions gs
SET 
  completed = true,
  end_time = COALESCE(gs.end_time, NOW())
FROM session_stats ss
WHERE gs.session_id = ss.session_id;

-- Update statistics for all existing sessions
UPDATE game_sessions gs
SET
  correct_words = stats.correct_count,
  average_response_time = stats.avg_response_time
FROM (
  SELECT 
    wa.session_id,
    COUNT(*) FILTER (WHERE wa.is_correct = true) as correct_count,
    AVG(wa.response_time_ms) as avg_response_time
  FROM word_attempts wa
  GROUP BY wa.session_id
) stats
WHERE gs.session_id = stats.session_id;