/*
  # Add attempt count column to word_attempts table

  1. Changes
    - Add `v_attempt_count` column to `word_attempts` table to track the number of attempts for each word
    
  2. Notes
    - Column is nullable to maintain compatibility with existing records
    - Default value is set to 1 for new records
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'word_attempts' 
    AND column_name = 'v_attempt_count'
  ) THEN
    ALTER TABLE word_attempts 
    ADD COLUMN v_attempt_count integer DEFAULT 1;
  END IF;
END $$;