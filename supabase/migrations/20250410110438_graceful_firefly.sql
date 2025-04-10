/*
  # Update achievements with translations
  
  1. Changes
    - Add columns for name translations
    - Add columns for description translations
    - Update existing achievements with translations
    
  2. Purpose
    - Support multilingual achievements
    - Display achievements in user's preferred language
*/

-- Add translation columns
ALTER TABLE achievements
ADD COLUMN IF NOT EXISTS name_en text,
ADD COLUMN IF NOT EXISTS name_de text,
ADD COLUMN IF NOT EXISTS description_en text,
ADD COLUMN IF NOT EXISTS description_de text;

-- Update existing achievements with translations
UPDATE achievements SET
  name_en = 'Language Apprentice',
  name_de = 'Sprachlehrling',
  description_en = 'Master more and more words to unlock levels',
  description_de = 'Beherrsche immer mehr Wörter, um Level freizuschalten'
WHERE condition_type = 'words_mastered_parent';

-- Update tiered achievements
UPDATE achievements SET
  name_en = CASE condition_value
    WHEN 10 THEN 'Word Beginner'
    WHEN 25 THEN 'Letter Amateur'
    WHEN 50 THEN 'Vocabulary Explorer'
    WHEN 75 THEN 'Word Curious'
    WHEN 100 THEN 'Word Collector'
    WHEN 125 THEN 'Spelling Detective'
    WHEN 150 THEN 'Word Hunter'
    WHEN 175 THEN 'Syllable Expert'
    WHEN 200 THEN 'Letter Archivist'
    WHEN 250 THEN 'Lexicon Master'
    WHEN 300 THEN 'Difficult Words Tamer'
    WHEN 350 THEN 'Language Scholar'
    WHEN 400 THEN 'Dictation Genius'
    WHEN 450 THEN 'Virtual Scribe'
    WHEN 500 THEN 'Spelling Professor'
  END,
  name_de = CASE condition_value
    WHEN 10 THEN 'Wortanfänger'
    WHEN 25 THEN 'Buchstabenliebhaber'
    WHEN 50 THEN 'Wortschatzerforscher'
    WHEN 75 THEN 'Wortneugieriger'
    WHEN 100 THEN 'Wortsammler'
    WHEN 125 THEN 'Rechtschreibdetektiv'
    WHEN 150 THEN 'Wortjäger'
    WHEN 175 THEN 'Silbenexperte'
    WHEN 200 THEN 'Buchstabenarchivator'
    WHEN 250 THEN 'Lexikonmeister'
    WHEN 300 THEN 'Schwierige-Wörter-Bändiger'
    WHEN 350 THEN 'Sprachgelehrter'
    WHEN 400 THEN 'Diktatgenie'
    WHEN 450 THEN 'Virtueller Schreiber'
    WHEN 500 THEN 'Rechtschreibprofessor'
  END,
  description_en = CASE condition_value
    WHEN 10 THEN 'Master 10 words'
    WHEN 25 THEN 'Master 25 words'
    WHEN 50 THEN 'Master 50 words'
    WHEN 75 THEN 'Master 75 words'
    WHEN 100 THEN 'Master 100 words'
    WHEN 125 THEN 'Master 125 words'
    WHEN 150 THEN 'Master 150 words'
    WHEN 175 THEN 'Master 175 words'
    WHEN 200 THEN 'Master 200 words'
    WHEN 250 THEN 'Master 250 words'
    WHEN 300 THEN 'Master 300 words'
    WHEN 350 THEN 'Master 350 words'
    WHEN 400 THEN 'Master 400 words'
    WHEN 450 THEN 'Master 450 words'
    WHEN 500 THEN 'Master 500 words'
  END,
  description_de = CASE condition_value
    WHEN 10 THEN 'Beherrsche 10 Wörter'
    WHEN 25 THEN 'Beherrsche 25 Wörter'
    WHEN 50 THEN 'Beherrsche 50 Wörter'
    WHEN 75 THEN 'Beherrsche 75 Wörter'
    WHEN 100 THEN 'Beherrsche 100 Wörter'
    WHEN 125 THEN 'Beherrsche 125 Wörter'
    WHEN 150 THEN 'Beherrsche 150 Wörter'
    WHEN 175 THEN 'Beherrsche 175 Wörter'
    WHEN 200 THEN 'Beherrsche 200 Wörter'
    WHEN 250 THEN 'Beherrsche 250 Wörter'
    WHEN 300 THEN 'Beherrsche 300 Wörter'
    WHEN 350 THEN 'Beherrsche 350 Wörter'
    WHEN 400 THEN 'Beherrsche 400 Wörter'
    WHEN 450 THEN 'Beherrsche 450 Wörter'
    WHEN 500 THEN 'Beherrsche 500 Wörter'
  END
WHERE condition_type = 'words_mastered';

-- Update other achievements
UPDATE achievements SET
  name_en = 'First Word Written',
  name_de = 'Erstes Wort geschrieben',
  description_en = 'Successfully write your first word correctly',
  description_de = 'Schreibe dein erstes Wort erfolgreich richtig'
WHERE condition_type = 'first_word';

UPDATE achievements SET
  name_en = 'Spelling Master',
  name_de = 'Rechtschreibmeister',
  description_en = 'Get a perfect score',
  description_de = 'Erreiche eine perfekte Punktzahl'
WHERE condition_type = 'perfect_score';

UPDATE achievements SET
  name_en = 'Speed',
  name_de = 'Schnelligkeit',
  description_en = 'Write a word correctly in less than 5 seconds',
  description_de = 'Schreibe ein Wort in weniger als 5 Sekunden richtig'
WHERE condition_type = 'fast_response';

UPDATE achievements SET
  name_en = 'Perfect Series',
  name_de = 'Perfekte Serie',
  description_en = 'Write 10/10 words in a row without error',
  description_de = 'Schreibe 10/10 Wörter hintereinander ohne Fehler'
WHERE condition_type = 'perfect_streak';