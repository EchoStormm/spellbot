import { LANGUAGE_VOICES } from '../types/openai';
import { generateSpeech } from './openai';

interface TTSOptions {
  onStart?: () => void;
  onEnd?: () => void;
  onError?: (error: Error) => void;
}

class TTSService {
  private audio: HTMLAudioElement | null = null;
  private isPlaying = false;

  private formatTime() {
    return new Date().toISOString();
  }

  async speak(text: string, language: string, options: TTSOptions = {}) {
    try {
      if (this.isPlaying) {
        console.log(`[${this.formatTime()}] TTS: Stopping previous playback`);
        this.stop();
      }

      console.log(`[${this.formatTime()}] TTS: Initializing playback
        Text: "${text}"
        Language: ${language}
        Voice: ${LANGUAGE_VOICES[language]?.voice || 'default'}
      `);

      options.onStart?.();
      this.isPlaying = true;

      console.log(`[${this.formatTime()}] TTS: Sending request to OpenAI API
        Model: tts-1
        Voice: ${LANGUAGE_VOICES[language]?.voice}
        Text length: ${text.length} characters
      `);

      const audioData = await generateSpeech(text, language);
      
      console.log(`[${this.formatTime()}] TTS: Received response from OpenAI API
        Response type: ArrayBuffer
        Data size: ${audioData.byteLength} bytes
      `);

      const audioBlob = new Blob([audioData], { type: 'audio/mpeg' });
      const audioUrl = URL.createObjectURL(audioBlob);

      this.audio = new Audio(audioUrl);

      this.audio.addEventListener('ended', () => {
        console.log(`[${this.formatTime()}] TTS: Audio playback completed
          Duration: ${this.audio?.duration.toFixed(2)}s
        `);
        this.cleanup();
        options.onEnd?.();
      });

      this.audio.addEventListener('error', (e) => {
        console.error(`[${this.formatTime()}] TTS: Audio playback error
          Error: ${e.type}
          Message: ${(e as ErrorEvent).message || 'Unknown error'}
        `);
        this.cleanup();
        options.onError?.(new Error('Audio playback failed'));
      });

      console.log(`[${this.formatTime()}] TTS: Starting audio playback`);
      await this.audio.play();
    } catch (error) {
      console.error(`[${this.formatTime()}] TTS: Critical error
        Type: ${error instanceof Error ? error.constructor.name : 'Unknown'}
        Message: ${error instanceof Error ? error.message : 'Unknown error'}
        Stack: ${error instanceof Error ? error.stack : 'Not available'}
      `);
      this.cleanup();
      options.onError?.(error instanceof Error ? error : new Error('TTS failed'));
    }
  }

  stop() {
    if (this.audio) {
      console.log(`[${this.formatTime()}] TTS: Manually stopping playback`);
      this.audio.pause();
      this.cleanup();
    }
  }

  private cleanup() {
    if (this.audio?.src) {
      console.log(`[${this.formatTime()}] TTS: Cleaning up resources
        URL: ${this.audio.src.substring(0, 50)}...
      `);
      URL.revokeObjectURL(this.audio.src);
    }
    this.audio = null;
    this.isPlaying = false;
  }
}

export const tts = new TTSService();