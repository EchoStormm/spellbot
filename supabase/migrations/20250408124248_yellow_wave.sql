/*
  # Clear all data except users

  1. Changes
    - Safely remove all data from game-related tables
    - Preserve user accounts and authentication
    - Re-insert default achievements
    
  2. Purpose
    - Start fresh with clean data
    - Maintain user accounts
    - Remove any test/development data
*/

-- Truncate all tables in the correct order
TRUNCATE TABLE 
  word_attempts,
  game_sessions,
  user_statistics,
  user_achievements,
  spaced_repetition_progress,
  words,
  achievements
CASCADE;

-- Re-insert default achievements
INSERT INTO achievements (name, description, condition_type, condition_value, icon_name) VALUES
  ('First Steps', 'Complete your first game session', 'sessions_completed', 1, 'award'),
  ('Perfect Score', 'Get 100% correct in a session', 'perfect_sessions', 1, 'star'),
  ('Word Master', 'Master 50 words', 'words_mastered', 50, 'book'),
  ('Speed Demon', 'Average response time under 2 seconds', 'response_time', 2000, 'timer'),
  ('Dedication', 'Complete 7 days streak', 'daily_streak', 7, 'calendar')
ON CONFLICT DO NOTHING;