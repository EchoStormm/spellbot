/*
  # Add v_attempt_count column to word_attempts table

  1. Changes
    - Add `v_attempt_count` column to `word_attempts` table with default value of 1
      - This column tracks the number of attempts for a word in a session
      - Default value of 1 represents the first attempt

  2. Notes
    - Column is nullable to maintain compatibility with existing records
    - Default value ensures new records have a starting count
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