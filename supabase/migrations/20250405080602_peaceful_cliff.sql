/*
  # Add RLS policies for words table

  1. Security Changes
    - Add policy to allow authenticated users to insert words
    - Add policy to allow authenticated users to read all words
    - These policies are needed because:
      a. Users need to be able to add new words for their games
      b. Users need to be able to read words during gameplay
      c. Words are shared resources that any authenticated user can access

  2. Notes
    - Words are considered public data once added
    - Any authenticated user can read any word
    - Any authenticated user can add new words
*/

-- Allow authenticated users to insert new words
CREATE POLICY "Words are insertable by authenticated users"
  ON words
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Allow authenticated users to read all words
-- This replaces the existing policy that was too restrictive
DROP POLICY IF EXISTS "Words are readable by authenticated users" ON words;
CREATE POLICY "Words are readable by authenticated users"
  ON words
  FOR SELECT
  TO authenticated
  USING (true);