/*
  # Add game session completion function

  1. New Functions
    - `update_game_session_completion`: Updates game session completion data
      - Parameters:
        - p_session_id: UUID of the session to update
        - p_end_time: Timestamp when the session ended
        - p_completed: Boolean indicating completion status
        - p_correct_words: Number of correctly answered words
        - p_average_response_time: Average response time in milliseconds

  2. Security
    - Function is accessible to authenticated users only
    - Users can only update their own game sessions
*/

CREATE OR REPLACE FUNCTION update_game_session_completion(
  p_session_id uuid,
  p_end_time timestamptz,
  p_completed boolean,
  p_correct_words integer,
  p_average_response_time double precision
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE game_sessions
  SET 
    end_time = p_end_time,
    completed = p_completed,
    correct_words = p_correct_words,
    average_response_time = p_average_response_time
  WHERE 
    session_id = p_session_id
    AND user_id = auth.uid();
END;
$$;