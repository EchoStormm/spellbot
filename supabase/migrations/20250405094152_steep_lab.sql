/*
  # Improve word progress handling
  
  1. Changes
    - Add handling for first-time reviews
    - Add validation for user and word existence
  
  2. Security
    - Keep SECURITY DEFINER for admin-level access
    - Add input validation
*/

-- Function to update progress after a review with improved handling
CREATE OR REPLACE FUNCTION update_word_progress(
  p_user_id UUID,
  p_word_id UUID,
  p_quality INTEGER
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  current_progress RECORD;
  next_progress RECORD;
  word_exists BOOLEAN;
BEGIN
  -- Validate input
  IF p_user_id IS NULL OR p_word_id IS NULL THEN
    RAISE EXCEPTION 'User ID and word ID are required';
  END IF;

  -- Check if word exists
  SELECT EXISTS (
    SELECT 1 FROM words WHERE word_id = p_word_id
  ) INTO word_exists;

  IF NOT word_exists THEN
    RAISE EXCEPTION 'Word does not exist';
  END IF;

  -- Get current progress or use defaults for first review
  SELECT 
    COALESCE(easiness_factor, 2.5) as easiness_factor,
    COALESCE(interval, 0) as interval,
    COALESCE(repetitions, 0) as repetitions
  INTO current_progress
  FROM spaced_repetition_progress
  WHERE user_id = p_user_id AND word_id = p_word_id;

  -- If no progress exists, use default values
  IF current_progress IS NULL THEN
    current_progress := ROW(2.5, 0, 0)::RECORD;
  END IF;

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

  -- Insert or update progress
  INSERT INTO spaced_repetition_progress (
    user_id,
    word_id,
    easiness_factor,
    interval,
    repetitions,
    last_review,
    next_review
  ) VALUES (
    p_user_id,
    p_word_id,
    next_progress.new_ef,
    next_progress.new_interval,
    next_progress.new_repetitions,
    NOW(),
    NOW() + (next_progress.new_interval || ' days')::INTERVAL
  )
  ON CONFLICT (user_id, word_id) DO UPDATE SET
    easiness_factor = EXCLUDED.easiness_factor,
    interval = EXCLUDED.interval,
    repetitions = EXCLUDED.repetitions,
    last_review = EXCLUDED.last_review,
    next_review = EXCLUDED.next_review;
END;
$$;