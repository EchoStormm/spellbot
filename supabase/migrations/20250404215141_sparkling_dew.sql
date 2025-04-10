/*
  # Add display name to users

  1. Changes
    - Add display_name column to auth.users table
    - Create function to update display_name
    - Create trigger to set initial display_name from email
*/

-- Add display_name column to auth.users
ALTER TABLE auth.users 
ADD COLUMN IF NOT EXISTS display_name text;

-- Function to extract username from email
CREATE OR REPLACE FUNCTION public.set_display_name()
RETURNS trigger AS $$
BEGIN
  IF NEW.display_name IS NULL THEN
    NEW.display_name := split_part(NEW.email, '@', 1);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to set display_name on user creation
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'set_initial_display_name'
  ) THEN
    CREATE TRIGGER set_initial_display_name
    BEFORE INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.set_display_name();
  END IF;
END $$;

-- Update existing users without display_name
UPDATE auth.users
SET display_name = split_part(email, '@', 1)
WHERE display_name IS NULL;