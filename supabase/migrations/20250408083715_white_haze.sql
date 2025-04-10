/*
  # Fix word_attempts RLS policies

  1. Changes
    - Drop existing policies for word_attempts table
    - Create new policies for:
      - INSERT: Allow authenticated users to insert their own attempts
      - SELECT: Allow authenticated users to view their own attempts
      - UPDATE: Prevent any updates (attempts should be immutable)
      - DELETE: Prevent any deletions (attempts should be permanent)

  2. Security
    - Maintains RLS enabled
    - Ensures users can only access their own data
    - Prevents modification of historical attempt data
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can insert own word attempts" ON word_attempts;
DROP POLICY IF EXISTS "Users can view own word attempts" ON word_attempts;

-- Create comprehensive policies
CREATE POLICY "Users can insert own word attempts"
ON word_attempts
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id AND
  EXISTS (
    SELECT 1 FROM game_sessions
    WHERE session_id = word_attempts.session_id
    AND user_id = auth.uid()
  )
);

CREATE POLICY "Users can view own word attempts"
ON word_attempts
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);