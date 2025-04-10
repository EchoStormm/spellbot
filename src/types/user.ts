export type EducationLevel = 'primary' | 'secondary' | 'college' | 'university';
export type AppLanguage = 'fr' | 'en' | 'de';

export const EDUCATION_LEVELS = [
  { value: 'primary', label: 'École primaire' },
  { value: 'secondary', label: 'École secondaire' },
  { value: 'college', label: 'Cégep' },
  { value: 'university', label: 'Université' }
];

export const APP_LANGUAGES = [
  { value: 'fr' as const, label: 'Français / French' },
  { value: 'en' as const, label: 'English / English' },
  { value: 'de' as const, label: 'Deutsch / German' }
];