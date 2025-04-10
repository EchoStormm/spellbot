/*
  # Update achievements display and add missing tiers
  
  1. Changes
    - Add parent_achievement_id to track achievement tiers
    - Add tier_level column for ordering
    - Update existing achievements with tier information
    - Add function to handle tier progression
    
  2. Purpose
    - Improve achievement tier display
    - Enable proper progression tracking
    - Fix achievement hierarchy
*/

-- Add columns for tier tracking
ALTER TABLE achievements
ADD COLUMN IF NOT EXISTS parent_achievement_id uuid REFERENCES achievements(achievement_id),
ADD COLUMN IF NOT EXISTS tier_level integer;

-- Create parent achievement for "Apprenti Linguiste"
WITH parent_achievement AS (
  INSERT INTO achievements (
    name,
    description,
    condition_type,
    condition_value,
    icon_name,
    tier_level
  ) VALUES (
    'Apprenti Linguiste',
    'Maîtrisez de plus en plus de mots pour débloquer des niveaux',
    'words_mastered_parent',
    0,
    'book',
    0
  ) RETURNING achievement_id
)
-- Update existing word mastery achievements to reference parent
UPDATE achievements a
SET 
  parent_achievement_id = parent_achievement.achievement_id,
  tier_level = CASE condition_value
    WHEN 10 THEN 1
    WHEN 25 THEN 2
    WHEN 50 THEN 3
    WHEN 75 THEN 4
    WHEN 100 THEN 5
    WHEN 125 THEN 6
    WHEN 150 THEN 7
    WHEN 175 THEN 8
    WHEN 200 THEN 9
    WHEN 250 THEN 10
    WHEN 300 THEN 11
    WHEN 350 THEN 12
    WHEN 400 THEN 13
    WHEN 450 THEN 14
    WHEN 500 THEN 15
  END
FROM parent_achievement
WHERE condition_type = 'words_mastered';

-- Function to check achievements including tiers
CREATE OR REPLACE FUNCTION check_word_achievements()
RETURNS TRIGGER AS $$
DECLARE
  mastered_words INTEGER;
  achievement RECORD;
  current_tier RECORD;
  next_tier RECORD;
BEGIN
  -- Get current mastered words count
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
    ORDER BY tier_level ASC
  LOOP
    -- If we've reached this tier and don't have it yet
    IF mastered_words >= achievement.condition_value AND NOT EXISTS (
      SELECT 1 FROM user_achievements
      WHERE user_id = NEW.user_id
      AND achievement_id = achievement.achievement_id
    ) THEN
      -- Award the achievement
      INSERT INTO user_achievements (user_id, achievement_id)
      VALUES (NEW.user_id, achievement.achievement_id);
      
      -- Also award the parent achievement if not already awarded
      IF NOT EXISTS (
        SELECT 1 FROM user_achievements ua
        JOIN achievements a ON ua.achievement_id = a.achievement_id
        WHERE ua.user_id = NEW.user_id
        AND a.condition_type = 'words_mastered_parent'
      ) THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        SELECT NEW.user_id, achievement_id
        FROM achievements
        WHERE condition_type = 'words_mastered_parent';
      END IF;
      
      RAISE LOG 'Awarded tier achievement: % to user % (mastered words: %)',
        achievement.name, NEW.user_id, mastered_words;
    END IF;
  END LOOP;

  -- Check other achievements (existing logic)
  IF NEW.is_correct THEN
    -- First word achievement
    IF NOT EXISTS (
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

    -- Speed achievement
    IF NEW.response_time_ms < 5000 AND NOT EXISTS (
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
  END IF;

  -- Perfect score achievement
  IF EXISTS (
    SELECT 1
    FROM game_sessions gs
    WHERE gs.session_id = NEW.session_id
    AND gs.total_words >= 10
    AND gs.correct_words = gs.total_words
  ) AND NOT EXISTS (
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

  -- Perfect streak achievement
  WITH attempts AS (
    SELECT 
      wa.is_correct,
      wa.created_at,
      ROW_NUMBER() OVER (ORDER BY wa.created_at DESC) as rn
    FROM word_attempts wa
    JOIN game_sessions gs ON wa.session_id = gs.session_id
    WHERE gs.user_id = NEW.user_id
  ),
  streak_calc AS (
    SELECT
      is_correct,
      SUM(CASE WHEN is_correct THEN 1 ELSE 0 END) OVER (ORDER BY created_at DESC) as streak
    FROM attempts
    WHERE rn <= 10
  )
  SELECT 1
  FROM streak_calc
  WHERE streak >= 10
  LIMIT 1;

  IF FOUND AND NOT EXISTS (
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
  mastered_words INTEGER;
BEGIN
  FOR user_record IN SELECT DISTINCT user_id FROM game_sessions LOOP
    -- Count mastered words
    SELECT COUNT(DISTINCT wa.word_id)
    INTO mastered_words
    FROM word_attempts wa
    JOIN game_sessions gs ON wa.session_id = gs.session_id
    WHERE gs.user_id = user_record.user_id
    AND wa.is_correct = true;

    -- Award parent achievement if any tier is unlocked
    IF mastered_words >= 10 THEN
      INSERT INTO user_achievements (user_id, achievement_id)
      SELECT user_record.user_id, achievement_id
      FROM achievements
      WHERE condition_type = 'words_mastered_parent'
      ON CONFLICT DO NOTHING;
    END IF;

    -- Award appropriate tier achievements
    INSERT INTO user_achievements (user_id, achievement_id)
    SELECT 
      user_record.user_id,
      achievement_id
    FROM achievements
    WHERE condition_type = 'words_mastered'
    AND condition_value <= mastered_words
    ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$;