/*
  # Add achievement translations table
  
  1. New Tables
    - `achievement_translations`
      - `achievement_id` (uuid, references achievements)
      - `language_code` (text, language code)
      - `name` (text, translated name)
      - `description` (text, translated description)
      
  2. Changes
    - Add translations for all achievements
    - Add foreign key constraints and indexes
*/

-- Create achievement translations table
CREATE TABLE IF NOT EXISTS achievement_translations (
  achievement_id uuid REFERENCES achievements(achievement_id) NOT NULL,
  language_code text NOT NULL,
  name text NOT NULL,
  description text NOT NULL,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (achievement_id, language_code)
);

-- Enable RLS
ALTER TABLE achievement_translations ENABLE ROW LEVEL SECURITY;

-- Add policy to allow reading translations
CREATE POLICY "Achievement translations are readable by authenticated users"
  ON achievement_translations
  FOR SELECT
  TO authenticated
  USING (true);

-- Insert translations for all achievements
INSERT INTO achievement_translations (achievement_id, language_code, name, description)
SELECT 
  achievement_id,
  'en',
  COALESCE(name_en, name),
  COALESCE(description_en, description)
FROM achievements;

INSERT INTO achievement_translations (achievement_id, language_code, name, description)
SELECT 
  achievement_id,
  'fr',
  name,
  description
FROM achievements;

INSERT INTO achievement_translations (achievement_id, language_code, name, description)
SELECT 
  achievement_id,
  'de',
  COALESCE(name_de, name),
  COALESCE(description_de, description)
FROM achievements;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS achievement_translations_lookup_idx 
ON achievement_translations(achievement_id, language_code);

-- Drop old translation columns as they're no longer needed
ALTER TABLE achievements
DROP COLUMN IF EXISTS name_en,
DROP COLUMN IF EXISTS name_de,
DROP COLUMN IF EXISTS description_en,
DROP COLUMN IF EXISTS description_de;