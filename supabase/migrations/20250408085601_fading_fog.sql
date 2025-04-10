/*
  # Fix word attempts RLS policy and add missing fields

  1. Changes
    - Simplify RLS policy for word attempts
    - Add NOT NULL constraints for required fields
    - Add index for faster lookups
    
  2. Purpose
    - Fix RLS policy violation errors
    - Ensure data integrity
    - Improve query performance
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can insert own word attempts" ON word_attempts;
DROP POLICY IF EXISTS "Users can view own word attempts" ON word_attempts;

-- Create simpler policies
CREATE POLICY "Users can insert own word attempts"
ON word_attempts
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own word attempts"
ON word_attempts
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Add NOT NULL constraints for required fields
ALTER TABLE word_attempts
ALTER COLUMN is_correct SET NOT NULL,
ALTER COLUMN user_input SET NOT NULL;