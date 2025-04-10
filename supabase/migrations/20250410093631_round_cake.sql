/*
  # Add new achievements for first word, perfect score, speed, and streaks
  
  1. New Achievements
    - Premier Mot Écrit: First word written correctly
    - Maître de l'Orthographe: Perfect score
    - Rapidité: Write a word in under 5 seconds
    - Série Parfaite: Write 10/10 words correctly in a row
    
  2. Changes
    - Add new achievements to achievements table
    - Add trigger to check for these achievements
    - Update existing trigger to handle new achievement types
*/

-- Add new achievements
INSERT INTO achievements (name, description, condition_type, condition_value, icon_name) VALUES
  ('Premier Mot Écrit', 'Réussir à écrire son premier mot correctement', 'first_word', 1, 'award'),
  ('Maître de l''Orthographe', 'Avoir zéro faute', 'perfect_score', 1, 'star'),
  ('Rapidité', 'Écrire un mot correctement en moins de 5 secondes', 'fast_response', 5000, 'timer'),
  ('Série Parfaite', 'Écrire 10/10 mots de suite sans erreur', 'perfect_streak', 10, 'star');

-- Function to check for speed and accuracy achievements
CREATE OR REPLACE FUNCTION check_word_achievements()
RETURNS TRIGGER AS $$
DECLARE
  mastered_words INTEGER;
  achievement RECORD;
  session_total_words INTEGER;
  session_correct_words INTEGER;
  current_streak INTEGER;
BEGIN
  -- Check for first word achievement
  IF NEW.is_correct AND NOT EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON ua.achievement_id = a.achievement_id
    WHERE ua.user_id = NEW.user_id
    AND a.condition_type = 'first_word'
  ) THEN
    INSERT INTO user_achievements (user_id, achievement_id)
    SELECT NEW.user_id, achievement_id
    FROM achievements
    WHERE condition_type = 'first_word';
  END IF;

  -- Check for speed achievement
  IF NEW.is_correct 
  AND NEW.response_time_ms < 5000 
  AND NOT EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON ua.achievement_id = a.achievement_id
    WHERE ua.user_id = NEW.user_id
    AND a.condition_type = 'fast_response'
  ) THEN
    INSERT INTO user_achievements (user_id, achievement_id)
    SELECT NEW.user_id, achievement_id
    FROM achievements
    WHERE condition_type = 'fast_response';
  END IF;

  -- Get session info
  SELECT 
    gs.total_words,
    COUNT(*) FILTER (WHERE wa.is_correct) as correct_count
  INTO 
    session_total_words,
    session_correct_words
  FROM game_sessions gs
  LEFT JOIN word_attempts wa ON wa.session_id = NEW.session_id
  WHERE gs.session_id = NEW.session_id
  GROUP BY gs.total_words;

  -- Check for perfect score achievement
  IF session_total_words = session_correct_words 
  AND session_total_words >= 10
  AND NOT EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON ua.achievement_id = a.achievement_id
    WHERE ua.user_id = NEW.user_id
    AND a.condition_type = 'perfect_score'
  ) THEN
    INSERT INTO user_achievements (user_id, achievement_id)
    SELECT NEW.user_id, achievement_id
    FROM achievements
    WHERE condition_type = 'perfect_score';
  END IF;

  -- Calculate current streak
  WITH attempts AS (
    SELECT 
      wa.is_correct,
      wa.created_at,
      ROW_NUMBER() OVER (ORDER BY wa.created_at DESC) as rn
    FROM word_attempts wa
    JOIN game_sessions gs ON wa.session_id = gs.session_id
    WHERE gs.user_id = NEW.user_id
    ORDER BY wa.created_at DESC
  ),
  streak_calc AS (
    SELECT
      is_correct,
      SUM(CASE WHEN is_correct THEN 1 ELSE 0 END) OVER (ORDER BY created_at DESC) as streak
    FROM attempts
    WHERE rn <= 10
  )
  SELECT MAX(streak) INTO current_streak
  FROM streak_calc
  WHERE is_correct;

  -- Check for perfect streak achievement
  IF current_streak >= 10 
  AND NOT EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON ua.achievement_id = a.achievement_id
    WHERE ua.user_id = NEW.user_id
    AND a.condition_type = 'perfect_streak'
  ) THEN
    INSERT INTO user_achievements (user_id, achievement_id)
    SELECT NEW.user_id, achievement_id
    FROM achievements
    WHERE condition_type = 'perfect_streak';
  END IF;

  -- Check word mastery achievements (existing logic)
  SELECT COUNT(DISTINCT wa.word_id)
  INTO mastered_words
  FROM word_attempts wa
  JOIN game_sessions gs ON wa.session_id = gs.session_id
  WHERE gs.user_id = NEW.user_id
  AND wa.is_correct = true;

  FOR achievement IN
    SELECT * FROM achievements 
    WHERE condition_type = 'words_mastered'
    ORDER BY condition_value ASC
  LOOP
    IF mastered_words >= achievement.condition_value AND NOT EXISTS (
      SELECT 1 FROM user_achievements
      WHERE user_id = NEW.user_id
      AND achievement_id = achievement.achievement_id
    ) THEN
      INSERT INTO user_achievements (user_id, achievement_id)
      VALUES (NEW.user_id, achievement.achievement_id);
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS check_word_achievements_trigger ON word_attempts;
CREATE TRIGGER check_word_achievements_trigger
  AFTER INSERT ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION check_word_achievements();

-- Recalculate achievements for existing users
DO $$
DECLARE
  user_record RECORD;
  fast_attempt RECORD;
  perfect_session RECORD;
  perfect_streak RECORD;
BEGIN
  FOR user_record IN SELECT DISTINCT user_id FROM game_sessions LOOP
    -- Check for first word achievement
    IF EXISTS (
      SELECT 1 
      FROM word_attempts wa
      JOIN game_sessions gs ON wa.session_id = gs.session_id
      WHERE gs.user_id = user_record.user_id
      AND wa.is_correct = true
    ) THEN
      INSERT INTO user_achievements (user_id, achievement_id)
      SELECT user_record.user_id, achievement_id
      FROM achievements
      WHERE condition_type = 'first_word'
      ON CONFLICT DO NOTHING;
    END IF;

    -- Check for speed achievement
    SELECT 1 INTO fast_attempt
    FROM word_attempts wa
    JOIN game_sessions gs ON wa.session_id = gs.session_id
    WHERE gs.user_id = user_record.user_id
    AND wa.is_correct = true
    AND wa.response_time_ms < 5000
    LIMIT 1;

    IF FOUND THEN
      INSERT INTO user_achievements (user_id, achievement_id)
      SELECT user_record.user_id, achievement_id
      FROM achievements
      WHERE condition_type = 'fast_response'
      ON CONFLICT DO NOTHING;
    END IF;

    -- Check for perfect score achievement
    SELECT 1 INTO perfect_session
    FROM game_sessions gs
    WHERE gs.user_id = user_record.user_id
    AND gs.total_words >= 10
    AND gs.correct_words = gs.total_words
    LIMIT 1;

    IF FOUND THEN
      INSERT INTO user_achievements (user_id, achievement_id)
      SELECT user_record.user_id, achievement_id
      FROM achievements
      WHERE condition_type = 'perfect_score'
      ON CONFLICT DO NOTHING;
    END IF;

    -- Check for perfect streak
    WITH attempts AS (
      SELECT 
        wa.is_correct,
        wa.created_at,
        ROW_NUMBER() OVER (PARTITION BY gs.user_id ORDER BY wa.created_at DESC) as rn
      FROM word_attempts wa
      JOIN game_sessions gs ON wa.session_id = gs.session_id
      WHERE gs.user_id = user_record.user_id
    ),
    streak_calc AS (
      SELECT
        is_correct,
        SUM(CASE WHEN is_correct THEN 1 ELSE 0 END) OVER (ORDER BY created_at DESC) as streak
      FROM attempts
      WHERE rn <= 10
    )
    SELECT 1 INTO perfect_streak
    FROM streak_calc
    WHERE streak >= 10
    LIMIT 1;

    IF FOUND THEN
      INSERT INTO user_achievements (user_id, achievement_id)
      SELECT user_record.user_id, achievement_id
      FROM achievements
      WHERE condition_type = 'perfect_streak'
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
END;
$$;