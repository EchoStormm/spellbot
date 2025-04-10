/*
  # Add word validation function and trigger

  1. New Functions
    - validate_word_text: Checks if a word contains only letters
    - word_validation_trigger: Enforces validation rules on word insert/update

  2. Changes
    - Adds validation to prevent numbers and symbols in words
    - Only allows letters and basic punctuation (apostrophes, hyphens)
    - Throws error if validation fails
*/

-- Function to validate word text
CREATE OR REPLACE FUNCTION validate_word_text(word_text TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if the word contains only letters, apostrophes, and hyphens
  -- Allows for words like "isn't" or "well-being"
  IF word_text ~ '^[a-zA-ZÀ-ÿ]+[-''a-zA-ZÀ-ÿ]*[a-zA-ZÀ-ÿ]+$' THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$;

-- Trigger function to validate words before insert/update
CREATE OR REPLACE FUNCTION word_validation_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT validate_word_text(NEW.text) THEN
    RAISE EXCEPTION 'Word "%" contains invalid characters. Only letters, apostrophes, and hyphens are allowed.', NEW.text;
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger on words table
CREATE TRIGGER validate_word_before_save
  BEFORE INSERT OR UPDATE ON words
  FOR EACH ROW
  EXECUTE FUNCTION word_validation_trigger();