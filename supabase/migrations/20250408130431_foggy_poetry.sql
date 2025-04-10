/*
  # Add average response time to game sessions

  1. Changes
    - Add `average_response_time` column to `game_sessions` table
      - Type: double precision (float)
      - Default: 0
      - Nullable: true
      - Purpose: Store the average response time for a game session

  2. Notes
    - Uses safe migration pattern with IF NOT EXISTS check
    - Preserves existing data
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'game_sessions' 
    AND column_name = 'average_response_time'
  ) THEN
    ALTER TABLE game_sessions 
    ADD COLUMN average_response_time double precision DEFAULT 0;
  END IF;
END $$;