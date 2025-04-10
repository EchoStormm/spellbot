/*
  # Add RLS policies for user statistics table

  1. Changes
    - Add INSERT policy for user_statistics table
    - Add UPDATE policy for user_statistics table
    
  2. Security
    - Allow trigger function to insert/update statistics
    - Maintain existing read-only policy for users
*/

-- Add policy to allow trigger function to insert statistics
CREATE POLICY "Trigger can insert user statistics"
ON user_statistics
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Add policy to allow trigger function to update statistics
CREATE POLICY "Trigger can update user statistics"
ON user_statistics
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);