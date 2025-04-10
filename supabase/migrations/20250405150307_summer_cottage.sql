/*
  # Add statistics refresh function and triggers

  1. New Functions
    - refresh_user_statistics: Recalculates user statistics for a given period
    - update_user_statistics_on_completion: Trigger function for game session completion
    
  2. Changes
    - Add function to manually refresh statistics
    - Add trigger for automatic updates on game completion
    - Improve calculation accuracy
*/

-- Function to refresh user statistics for a given period
CREATE OR REPLACE FUNCTION refresh_user_statistics(
  p_user_id UUID,
  p_date DATE
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_period_start DATE;
  v_period_end DATE;
BEGIN
  -- Calculate period boundaries
  v_period_start := p_date;
  v_period_end := p_date + interval '1 day';

  -- Calculate and update daily statistics
  INSERT INTO user_statistics (
    user_id,
    period_start,
    period_type,
    total_sessions,
    total_words_attempted,
    total_words_correct,
    average_response_time,
    total_time_spent,
    updated_at
  )
  SELECT
    p_user_id,
    p_date,
    'daily',
    COUNT(DISTINCT gs.session_id),
    COUNT(wa.attempt_id),
    COUNT(DISTINCT CASE WHEN wa.is_correct THEN wa.word_id END),
    AVG(wa.response_time_ms),
    SUM(gs.end_time - gs.start_time),
    now()
  FROM game_sessions gs
  LEFT JOIN word_attempts wa ON gs.session_id = wa.session_id
  WHERE gs.user_id = p_user_id
    AND gs.created_at >= v_period_start
    AND gs.created_at < v_period_end
    AND gs.completed = true
  ON CONFLICT (user_id, period_start, period_type)
  DO UPDATE SET
    total_sessions = EXCLUDED.total_sessions,
    total_words_attempted = EXCLUDED.total_words_attempted,
    total_words_correct = EXCLUDED.total_words_correct,
    average_response_time = EXCLUDED.average_response_time,
    total_time_spent = EXCLUDED.total_time_spent,
    updated_at = EXCLUDED.updated_at;
END;
$$;

-- Function to update statistics when a game session is completed
CREATE OR REPLACE FUNCTION update_user_statistics_on_completion()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Only update statistics when a session is marked as completed
  IF NEW.completed = true AND (OLD.completed = false OR OLD.completed IS NULL) THEN
    PERFORM refresh_user_statistics(NEW.user_id, date_trunc('day', NEW.created_at)::date);
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger for automatic updates
CREATE TRIGGER update_statistics_on_game_completion
  AFTER UPDATE OF completed ON game_sessions
  FOR EACH ROW
  WHEN (NEW.completed = true AND (OLD.completed = false OR OLD.completed IS NULL))
  EXECUTE FUNCTION update_user_statistics_on_completion();

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION refresh_user_statistics TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_statistics_on_completion TO authenticated;