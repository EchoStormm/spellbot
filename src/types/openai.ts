export type Voice = 'alloy' | 'echo' | 'fable' | 'onyx' | 'nova' | 'shimmer';

interface VoiceConfig {
  voice: Voice;
  name: string;
}

export const LANGUAGE_VOICES: Record<string, VoiceConfig> = {
  en: { voice: 'nova', name: 'English (Female)' },
  fr: { voice: 'onyx', name: 'French (Neutral)' },
  de: { voice: 'onyx', name: 'German (Male)' }
};