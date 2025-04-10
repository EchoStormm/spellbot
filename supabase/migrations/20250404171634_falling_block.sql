/*
  # Create words and spaced repetition tables

  1. New Tables
    - `words`
      - `word_id` (uuid, primary key)
      - `text` (text, the actual word)
      - `language` (text, language code)
      - `created_at` (timestamp)
    
    - `spaced_repetition_progress`
      - `progress_id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `word_id` (uuid, references words)
      - `easiness_factor` (float, SM-2 algorithm parameter)
      - `interval` (integer, days until next review)
      - `repetitions` (integer, number of successful reviews)
      - `next_review` (timestamp, when to review next)
      - `last_review` (timestamp, last review date)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on both tables
    - Add policies for authenticated users
*/

-- Create words table
CREATE TABLE IF NOT EXISTS words (
  word_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  text text NOT NULL,
  language text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(text, language)
);

-- Create spaced repetition progress table
CREATE TABLE IF NOT EXISTS spaced_repetition_progress (
  progress_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  word_id uuid REFERENCES words NOT NULL,
  easiness_factor float NOT NULL DEFAULT 2.5,
  interval integer NOT NULL DEFAULT 0,
  repetitions integer NOT NULL DEFAULT 0,
  next_review timestamptz NOT NULL DEFAULT now(),
  last_review timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, word_id)
);

-- Enable RLS
ALTER TABLE words ENABLE ROW LEVEL SECURITY;
ALTER TABLE spaced_repetition_progress ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Words are readable by authenticated users"
  ON words
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Progress is readable by own user"
  ON spaced_repetition_progress
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Progress is insertable by own user"
  ON spaced_repetition_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Progress is updatable by own user"
  ON spaced_repetition_progress
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);