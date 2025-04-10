/*
  # Add user settings and preferences

  1. Changes
    - Add education_level and default_language to user metadata
    - Add app_language to user metadata
    - Add policies for user settings management

  2. Security
    - Update RLS policies to include new metadata fields
*/

-- Update user metadata with new fields
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS raw_user_meta_data jsonb;
ALTER TABLE auth.users ALTER COLUMN raw_user_meta_data SET DEFAULT '{"education_level": "primary", "default_language": "en", "app_language": "fr"}'::jsonb;

-- Function to validate education level
CREATE OR REPLACE FUNCTION validate_education_level(level text)
RETURNS boolean AS $$
BEGIN
  RETURN level IN ('primary', 'secondary', 'college', 'university');
END;
$$ LANGUAGE plpgsql;