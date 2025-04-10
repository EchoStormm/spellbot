/*
  # Update user profile schema

  1. Changes
    - Add RLS policies for user profile management
    - Add function to handle profile updates
    - Add trigger to sync profile changes

  2. Security
    - Enable RLS on auth.users
    - Add policies for users to update their own profile
*/

-- Create a function to handle profile updates
CREATE OR REPLACE FUNCTION handle_user_profile_update()
RETURNS TRIGGER AS $$
BEGIN
  -- Update spaced_repetition_progress user references if email changes
  IF OLD.email <> NEW.email THEN
    UPDATE spaced_repetition_progress
    SET user_id = NEW.id
    WHERE user_id = OLD.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a trigger to handle profile updates
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'on_user_profile_update'
  ) THEN
    CREATE TRIGGER on_user_profile_update
    AFTER UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_user_profile_update();
  END IF;
END $$;

-- Add RLS policies for user profile management
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
ON auth.users
FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON auth.users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);