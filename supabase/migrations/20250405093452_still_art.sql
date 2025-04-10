/*
  # Add SM-2 spaced repetition algorithm functions
  
  1. Changes
    - Add function to calculate next interval using SM-2 algorithm
    - Add function to update progress after review
    - Add quality rating constraints
  
  2. Algorithm Parameters
    - Quality ratings: 0-5 (0=wrong, 5=perfect)
    - Initial easiness factor: 2.5
    - Minimum easiness factor: 1.3
*/

-- Function to calculate next interval using SM-2 algorithm
CREATE OR REPLACE FUNCTION calculate_next_interval(
  quality INTEGER,
  current_ef FLOAT,
  current_interval INTEGER,
  current_repetitions INTEGER
) RETURNS TABLE (
  new_interval INTEGER,
  new_ef FLOAT,
  new_repetitions INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
  next_ef FLOAT;
  next_interval INTEGER;
  next_repetitions INTEGER;
BEGIN
  -- Validate quality rating
  IF quality < 0 OR quality > 5 THEN
    RAISE EXCEPTION 'Quality rating must be between 0 and 5';
  END IF;

  -- Calculate new easiness factor
  next_ef := current_ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  
  -- Ensure EF doesn't go below 1.3
  IF next_ef < 1.3 THEN
    next_ef := 1.3;
  END IF;

  -- Update repetitions and interval
  IF quality < 3 THEN
    -- If response was poor, reset repetitions and start over
    next_repetitions := 0;
    next_interval := 1;
  ELSE
    next_repetitions := current_repetitions + 1;
    
    -- Calculate next interval based on repetition number
    CASE next_repetitions
      WHEN 1 THEN
        next_interval := 1;
      WHEN 2 THEN
        next_interval := 6;
      ELSE
        next_interval := ROUND(current_interval * next_ef)::INTEGER;
    END CASE;
  END IF;

  RETURN QUERY SELECT 
    next_interval,
    next_ef,
    next_repetitions;
END;
$$;

-- Function to update progress after a review
CREATE OR REPLACE FUNCTION update_word_progress(
  p_user_id UUID,
  p_word_id UUID,
  p_quality INTEGER
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  current_progress RECORD;
  next_progress RECORD;
BEGIN
  -- Get current progress
  SELECT 
    easiness_factor,
    interval,
    repetitions
  INTO current_progress
  FROM spaced_repetition_progress
  WHERE user_id = p_user_id AND word_id = p_word_id;

  -- Calculate next interval and EF
  SELECT 
    new_interval,
    new_ef,
    new_repetitions
  INTO next_progress
  FROM calculate_next_interval(
    p_quality,
    current_progress.easiness_factor,
    current_progress.interval,
    current_progress.repetitions
  );

  -- Update progress
  UPDATE spaced_repetition_progress
  SET
    easiness_factor = next_progress.new_ef,
    interval = next_progress.new_interval,
    repetitions = next_progress.new_repetitions,
    last_review = NOW(),
    next_review = NOW() + (next_progress.new_interval || ' days')::INTERVAL
  WHERE user_id = p_user_id AND word_id = p_word_id;
END;
$$;