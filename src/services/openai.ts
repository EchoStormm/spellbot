import { supabase } from '../lib/supabase';

export async function generateSpeech(text: string, language: string): Promise<ArrayBuffer> {
  console.log(`[${new Date().toISOString()}] Speech Generation Request:
    Text length: ${text.length} characters
    Language: ${language}
  `);

  const startTime = Date.now();

  try {
    const response = await supabase.functions.invoke('secrets', {
      body: { text, language },
      responseType: 'arrayBuffer'
    });

    if (response.error) {
      console.error('Error generating speech:', response.error);
      if (response.error.message.includes('CORS')) {
        throw new Error('CORS error: Please check your Supabase function configuration');
      }
      throw new Error('Failed to generate speech');
    }

    // Vérifiez que la réponse est bien un ArrayBuffer
    if (!(response.data instanceof ArrayBuffer)) {
      console.error('Invalid response format:', response.data);
      throw new Error('Invalid response format from TTS service');
    }

    const endTime = Date.now();
    console.log(`[${new Date().toISOString()}] Speech Generation Response:
      Status: Success
      Response time: ${endTime - startTime}ms
      Data type: ${response.data.constructor.name}
      Data size: ${response.data.byteLength} bytes
    `);

    return response.data;
  } catch (error) {
    console.error('Speech generation error:', error);
    throw error;
  }
}