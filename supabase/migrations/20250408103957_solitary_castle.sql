/*
  # Add average_response_time column to game_sessions

  1. Changes
    - Add `average_response_time` column to `game_sessions` table
      - Type: double precision (to match other response time columns)
      - Default: 0 (consistent with other numeric defaults)
      - Nullable: true (to match pattern of other statistics columns)

  2. Notes
    - This column is needed for tracking the average response time per game session
    - Matches the type used in user_statistics.statistics_average_response_time
*/

ALTER TABLE game_sessions
ADD COLUMN IF NOT EXISTS average_response_time double precision DEFAULT 0;

-- Ensure RLS policies continue to apply to the new column
ALTER TABLE game_sessions ENABLE ROW LEVEL SECURITY;