import { OpenAI } from 'openai';
import { LANGUAGE_VOICES } from '../types/openai';

const apiKey = import.meta.env.VITE_OPENAI_API_KEY;

if (!apiKey) {
  throw new Error('OpenAI API key is not set. Please add it to your .env file.');
}

const openai = new OpenAI({
  apiKey,
  dangerouslyAllowBrowser: true
});

export async function generateSpeech(text: string, language: string): Promise<ArrayBuffer> {
  const voiceConfig = LANGUAGE_VOICES[language] || LANGUAGE_VOICES.en;
  
  console.log(`[${new Date().toISOString()}] OpenAI API Request:
    Endpoint: /audio/speech
    Model: tts-1
    Voice: ${voiceConfig.voice}
    Text length: ${text.length} characters
    Language: ${language}
  `);

  const startTime = Date.now();

const response = await openai.audio.speech.create({
  model: 'tts-1-hd',
  voice: voiceConfig.voice,
  input: text,
  voice_settings: {
    stability: 0.75,
    similarity_boost: 0.6
  }
});
  
  const endTime = Date.now();
  console.log(`[${new Date().toISOString()}] OpenAI API Response:
    Status: Success
    Response time: ${endTime - startTime}ms
    Content type: ${response.headers.get('content-type')}
    Content length: ${response.headers.get('content-length')} bytes
  `);

  return response.arrayBuffer();
}