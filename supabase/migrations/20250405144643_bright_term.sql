/*
  # Remove redundant triggers and functions

  1. Changes
    - Drop redundant trigger from bright_jungle.sql
    - Keep the latest version of the trigger from wandering_hall.sql
    
  2. Purpose
    - Remove duplicate functionality
    - Maintain single source of truth for statistics updates
*/

-- Drop the redundant trigger
DROP TRIGGER IF EXISTS update_user_statistics ON game_sessions;