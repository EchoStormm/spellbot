import { supabase } from '../lib/supabase';

export async function generateSpeech(text: string, language: string): Promise<ArrayBuffer> {
  console.log(`[${new Date().toISOString()}] Speech Generation Request:
    Text length: ${text.length} characters
    Language: ${language}
  `);

  const startTime = Date.now();

  const { data, error } = await supabase.functions.invoke('secrets', {
    body: { text, language }
  });

  if (error) {
    console.error('Error generating speech:', error);
    throw new Error('Failed to generate speech');
  }

  const endTime = Date.now();
  console.log(`[${new Date().toISOString()}] Speech Generation Response:
    Status: Success
    Response time: ${endTime - startTime}ms
  `);

  return data;
}