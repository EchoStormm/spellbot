export interface Word {
  word_id: string;
  text: string;
  language: string;
  created_at: Date;
}

export interface SpacedRepetitionData {
  word_id: string;
  user_id: string;
  easiness_factor: number;
  interval: number;
  repetitions: number;
  next_review: Date;
  last_review: Date;
}

export type GameMode = 'custom' | 'spaced-repetition';

export interface Language {
  code: string;
  name: string;
}

export const SUPPORTED_LANGUAGES: Language[] = [
  { code: 'en', name: 'English / English' },
  { code: 'fr', name: 'Français / French' },
  { code: 'de', name: 'Deutsch / German' }
];