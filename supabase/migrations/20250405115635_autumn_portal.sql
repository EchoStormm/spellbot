/*
  # Fix statistics trigger variable assignment

  1. Changes
    - Fix variable assignment in update_user_statistics_trigger
    - Use local variable instead of trying to modify NEW record
    - Maintain all existing functionality

  2. Technical Details
    - Replace NEW.total_sessions with local variable
    - Keep unique word counting logic
    - Keep other statistics calculations
*/

CREATE OR REPLACE FUNCTION update_user_statistics_trigger()
RETURNS TRIGGER AS $$
DECLARE
  period_start_date date;
  total_unique_correct integer;
  total_attempts integer;
  avg_response_time double precision;
  total_duration interval;
  sessions_count integer;
BEGIN
  -- Get the start of the current day for the period
  period_start_date := date_trunc('day', COALESCE(NEW.end_time, now()))::date;

  -- Calculate unique correct words for the day
  WITH unique_correct_words AS (
    SELECT DISTINCT wa.word_id
    FROM word_attempts wa
    JOIN game_sessions gs ON wa.session_id = gs.session_id
    WHERE wa.user_id = NEW.user_id
      AND date_trunc('day', gs.created_at)::date = period_start_date
      AND wa.is_correct = true
  )
  SELECT count(*) INTO total_unique_correct
  FROM unique_correct_words;

  -- Calculate other statistics
  SELECT
    count(DISTINCT gs.session_id),
    count(wa.attempt_id),
    avg(wa.response_time_ms),
    sum(COALESCE(gs.end_time, now()) - gs.start_time)
  INTO
    sessions_count,
    total_attempts,
    avg_response_time,
    total_duration
  FROM game_sessions gs
  LEFT JOIN word_attempts wa ON gs.session_id = wa.session_id
  WHERE gs.user_id = NEW.user_id
    AND date_trunc('day', gs.created_at)::date = period_start_date;

  -- Insert or update the statistics record
  INSERT INTO user_statistics (
    user_id,
    period_start,
    period_type,
    total_sessions,
    total_words_attempted,
    total_words_correct,
    average_response_time,
    total_time_spent
  )
  VALUES (
    NEW.user_id,
    period_start_date,
    'daily',
    COALESCE(sessions_count, 0),
    total_attempts,
    total_unique_correct,
    avg_response_time,
    total_duration
  )
  ON CONFLICT (user_id, period_start, period_type)
  DO UPDATE SET
    total_sessions = EXCLUDED.total_sessions,
    total_words_attempted = EXCLUDED.total_words_attempted,
    total_words_correct = EXCLUDED.total_words_correct,
    average_response_time = EXCLUDED.average_response_time,
    total_time_spent = EXCLUDED.total_time_spent,
    updated_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;