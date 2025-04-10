/*
  # Fix average response time handling

  1. Changes
    - Update the update_session_stats function to properly handle average_response_time
    - Ensure the average_response_time column is properly updated when new attempts are added

  2. Technical Details
    - Modify the trigger function to calculate and update average_response_time
    - Handle NULL cases appropriately
*/

CREATE OR REPLACE FUNCTION public.update_session_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update game session statistics
  UPDATE public.game_sessions
  SET 
    correct_words = (
      SELECT COUNT(*) 
      FROM public.word_attempts 
      WHERE session_id = NEW.session_id AND is_correct = true
    ),
    average_response_time = (
      SELECT AVG(response_time_ms)::double precision
      FROM public.word_attempts
      WHERE session_id = NEW.session_id
    )
  WHERE session_id = NEW.session_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;