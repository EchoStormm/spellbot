/*
  # Add progressive word achievements system
  
  1. Changes
    - Add new word mastery achievements
    - Add trigger to track word progress
    - Update achievements table with new tiers
    
  2. Purpose
    - Add progression system for word mastery
    - Reward players for learning more words
    - Track learning milestones
*/

-- First, remove old achievements
DELETE FROM achievements;

-- Insert new tiered achievements
INSERT INTO achievements (name, description, condition_type, condition_value, icon_name) VALUES
  ('Débutant des Mots', 'Maîtrisez 10 mots', 'words_mastered', 10, 'book'),
  ('Amateur de Lettres', 'Maîtrisez 25 mots', 'words_mastered', 25, 'book'),
  ('Explorateur du Vocabulaire', 'Maîtrisez 50 mots', 'words_mastered', 50, 'book'),
  ('Curieux des Mots', 'Maîtrisez 75 mots', 'words_mastered', 75, 'book'),
  ('Collectionneur de Mots', 'Maîtrisez 100 mots', 'words_mastered', 100, 'book'),
  ('Détective Orthographique', 'Maîtrisez 125 mots', 'words_mastered', 125, 'book'),
  ('Chasseur de Mots', 'Maîtrisez 150 mots', 'words_mastered', 150, 'book'),
  ('Expert en Syllabes', 'Maîtrisez 175 mots', 'words_mastered', 175, 'book'),
  ('Archiviste des Lettres', 'Maîtrisez 200 mots', 'words_mastered', 200, 'book'),
  ('Maître du Lexique', 'Maîtrisez 250 mots', 'words_mastered', 250, 'book'),
  ('Dompteur de Mots Difficiles', 'Maîtrisez 300 mots', 'words_mastered', 300, 'book'),
  ('Savant du Langage', 'Maîtrisez 350 mots', 'words_mastered', 350, 'book'),
  ('Génie des Dictées', 'Maîtrisez 400 mots', 'words_mastered', 400, 'book'),
  ('Scribe Virtuel', 'Maîtrisez 450 mots', 'words_mastered', 450, 'book'),
  ('Professeur d''Orthographe', 'Maîtrisez 500 mots', 'words_mastered', 500, 'book');

-- Function to check and award word mastery achievements
CREATE OR REPLACE FUNCTION check_word_achievements()
RETURNS TRIGGER AS $$
DECLARE
  mastered_words INTEGER;
  achievement RECORD;
BEGIN
  -- Count total correct words for the user
  SELECT COUNT(DISTINCT wa.word_id)
  INTO mastered_words
  FROM word_attempts wa
  JOIN game_sessions gs ON wa.session_id = gs.session_id
  WHERE gs.user_id = NEW.user_id
  AND wa.is_correct = true;

  -- Check each achievement tier
  FOR achievement IN
    SELECT * FROM achievements 
    WHERE condition_type = 'words_mastered'
    ORDER BY condition_value ASC
  LOOP
    -- If we've reached this tier and don't have the achievement yet
    IF mastered_words >= achievement.condition_value AND NOT EXISTS (
      SELECT 1 FROM user_achievements
      WHERE user_id = NEW.user_id
      AND achievement_id = achievement.achievement_id
    ) THEN
      -- Award the achievement
      INSERT INTO user_achievements (user_id, achievement_id)
      VALUES (NEW.user_id, achievement.achievement_id);
      
      RAISE LOG 'Awarded achievement: % to user % (mastered words: %)',
        achievement.name, NEW.user_id, mastered_words;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to check achievements after each word attempt
DROP TRIGGER IF EXISTS check_word_achievements_trigger ON word_attempts;
CREATE TRIGGER check_word_achievements_trigger
  AFTER INSERT ON word_attempts
  FOR EACH ROW
  EXECUTE FUNCTION check_word_achievements();

-- Recalculate achievements for existing users
DO $$
DECLARE
  user_record RECORD;
  mastered_words INTEGER;
  achievement RECORD;
BEGIN
  FOR user_record IN SELECT DISTINCT user_id FROM game_sessions LOOP
    -- Count mastered words for this user
    SELECT COUNT(DISTINCT wa.word_id)
    INTO mastered_words
    FROM word_attempts wa
    JOIN game_sessions gs ON wa.session_id = gs.session_id
    WHERE gs.user_id = user_record.user_id
    AND wa.is_correct = true;

    -- Check each achievement tier
    FOR achievement IN
      SELECT * FROM achievements 
      WHERE condition_type = 'words_mastered'
      ORDER BY condition_value ASC
    LOOP
      -- If they've reached this tier and don't have the achievement
      IF mastered_words >= achievement.condition_value AND NOT EXISTS (
        SELECT 1 FROM user_achievements
        WHERE user_id = user_record.user_id
        AND achievement_id = achievement.achievement_id
      ) THEN
        -- Award the achievement
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (user_record.user_id, achievement.achievement_id);
      END IF;
    END LOOP;
  END LOOP;
END;
$$;