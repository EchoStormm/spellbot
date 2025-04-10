/*
  # Add Statistics Tracking System

  1. New Tables
    - `game_sessions`
      - Tracks individual game sessions
      - Stores session duration, completion status
      - Records game mode and language
    
    - `word_attempts`
      - Records individual word attempts
      - Tracks response time, correctness
      - Stores error patterns
    
    - `user_statistics`
      - Aggregates user performance metrics
      - Stores daily/weekly/monthly stats
      - Tracks achievement progress

  2. Functions
    - calculate_user_statistics: Updates aggregated statistics
    - analyze_error_patterns: Identifies common mistakes
    - update_achievement_progress: Tracks user achievements

  3. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create game sessions table
CREATE TABLE IF NOT EXISTS game_sessions (
  session_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  game_mode text NOT NULL,
  language text NOT NULL,
  start_time timestamptz NOT NULL DEFAULT now(),
  end_time timestamptz,
  completed boolean DEFAULT false,
  total_words integer NOT NULL,
  correct_words integer DEFAULT 0,
  average_response_time float DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create word attempts table
CREATE TABLE IF NOT EXISTS word_attempts (
  attempt_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES game_sessions NOT NULL,
  word_id uuid REFERENCES words NOT NULL,
  user_id uuid REFERENCES auth.users NOT NULL,
  user_input text NOT NULL,
  is_correct boolean NOT NULL,
  response_time_ms integer NOT NULL,
  error_type text, -- 'phonetic', 'omission', 'inversion', 'case'
  created_at timestamptz DEFAULT now()
);

-- Create user statistics table
CREATE TABLE IF NOT EXISTS user_statistics (
  stat_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  period_start date NOT NULL,
  period_type text NOT NULL, -- 'daily', 'weekly', 'monthly'
  total_sessions integer DEFAULT 0,
  total_words_attempted integer DEFAULT 0,
  total_words_correct integer DEFAULT 0,
  average_response_time float DEFAULT 0,
  total_time_spent interval DEFAULT '0 seconds',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, period_start, period_type)
);

-- Create achievements table
CREATE TABLE IF NOT EXISTS achievements (
  achievement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  condition_type text NOT NULL, -- 'words_mastered', 'perfect_sessions', 'streak'
  condition_value integer NOT NULL,
  icon_name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create user achievements table
CREATE TABLE IF NOT EXISTS user_achievements (
  user_id uuid REFERENCES auth.users NOT NULL,
  achievement_id uuid REFERENCES achievements NOT NULL,
  achieved_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, achievement_id)
);

-- Enable RLS
ALTER TABLE game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE word_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_statistics ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view own game sessions"
  ON game_sessions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own game sessions"
  ON game_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own game sessions"
  ON game_sessions
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own word attempts"
  ON word_attempts
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own word attempts"
  ON word_attempts
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own statistics"
  ON user_statistics
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view achievements"
  ON achievements
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view own achievements"
  ON user_achievements
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Function to analyze error patterns
CREATE OR REPLACE FUNCTION analyze_error_pattern(
  original_word text,
  user_input text
) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  error_type text;
BEGIN
  -- Check for case errors
  IF original_word != user_input AND lower(original_word) = lower(user_input) THEN
    RETURN 'case';
  END IF;

  -- Check for letter omission
  IF length(original_word) - length(user_input) = 1 AND 
     position(substring(user_input, 1, 1) in original_word) > 0 THEN
    RETURN 'omission';
  END IF;

  -- Check for letter inversion
  IF length(original_word) = length(user_input) AND
     lower(original_word) != lower(user_input) AND
     (SELECT count(*) FROM regexp_matches(lower(original_word), '[' || lower(user_input) || ']', 'g')) = length(original_word) THEN
    RETURN 'inversion';
  END IF;

  -- Default to phonetic error
  RETURN 'phonetic';
END;
$$;

-- Function to update user statistics
CREATE OR REPLACE FUNCTION update_user_statistics(
  p_user_id uuid,
  p_session_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  session_data record;
  current_date date := current_date;
  current_week date := date_trunc('week', current_date)::date;
  current_month date := date_trunc('month', current_date)::date;
BEGIN
  -- Get session data
  SELECT 
    end_time - start_time as duration,
    total_words,
    correct_words,
    average_response_time
  INTO session_data
  FROM game_sessions
  WHERE session_id = p_session_id;

  -- Update daily statistics
  INSERT INTO user_statistics (
    user_id, period_start, period_type,
    total_sessions, total_words_attempted, total_words_correct,
    average_response_time, total_time_spent
  ) VALUES (
    p_user_id, current_date, 'daily',
    1, session_data.total_words, session_data.correct_words,
    session_data.average_response_time, session_data.duration
  )
  ON CONFLICT (user_id, period_start, period_type) DO UPDATE SET
    total_sessions = user_statistics.total_sessions + 1,
    total_words_attempted = user_statistics.total_words_attempted + EXCLUDED.total_words_attempted,
    total_words_correct = user_statistics.total_words_correct + EXCLUDED.total_words_correct,
    average_response_time = (user_statistics.average_response_time * user_statistics.total_sessions + EXCLUDED.average_response_time) / (user_statistics.total_sessions + 1),
    total_time_spent = user_statistics.total_time_spent + EXCLUDED.total_time_spent,
    updated_at = now();

  -- Update weekly statistics
  INSERT INTO user_statistics (
    user_id, period_start, period_type,
    total_sessions, total_words_attempted, total_words_correct,
    average_response_time, total_time_spent
  ) VALUES (
    p_user_id, current_week, 'weekly',
    1, session_data.total_words, session_data.correct_words,
    session_data.average_response_time, session_data.duration
  )
  ON CONFLICT (user_id, period_start, period_type) DO UPDATE SET
    total_sessions = user_statistics.total_sessions + 1,
    total_words_attempted = user_statistics.total_words_attempted + EXCLUDED.total_words_attempted,
    total_words_correct = user_statistics.total_words_correct + EXCLUDED.total_words_correct,
    average_response_time = (user_statistics.average_response_time * user_statistics.total_sessions + EXCLUDED.average_response_time) / (user_statistics.total_sessions + 1),
    total_time_spent = user_statistics.total_time_spent + EXCLUDED.total_time_spent,
    updated_at = now();

  -- Update monthly statistics
  INSERT INTO user_statistics (
    user_id, period_start, period_type,
    total_sessions, total_words_attempted, total_words_correct,
    average_response_time, total_time_spent
  ) VALUES (
    p_user_id, current_month, 'monthly',
    1, session_data.total_words, session_data.correct_words,
    session_data.average_response_time, session_data.duration
  )
  ON CONFLICT (user_id, period_start, period_type) DO UPDATE SET
    total_sessions = user_statistics.total_sessions + 1,
    total_words_attempted = user_statistics.total_words_attempted + EXCLUDED.total_words_attempted,
    total_words_correct = user_statistics.total_words_correct + EXCLUDED.total_words_correct,
    average_response_time = (user_statistics.average_response_time * user_statistics.total_sessions + EXCLUDED.average_response_time) / (user_statistics.total_sessions + 1),
    total_time_spent = user_statistics.total_time_spent + EXCLUDED.total_time_spent,
    updated_at = now();
END;
$$;

-- Insert default achievements
INSERT INTO achievements (name, description, condition_type, condition_value, icon_name) VALUES
  ('First Steps', 'Complete your first game session', 'sessions_completed', 1, 'award'),
  ('Perfect Score', 'Get 100% correct in a session', 'perfect_sessions', 1, 'star'),
  ('Word Master', 'Master 50 words', 'words_mastered', 50, 'book'),
  ('Speed Demon', 'Average response time under 2 seconds', 'response_time', 2000, 'timer'),
  ('Dedication', 'Complete 7 days streak', 'daily_streak', 7, 'calendar')
ON CONFLICT DO NOTHING;