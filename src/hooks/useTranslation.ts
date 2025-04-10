import { useAuthStore } from '../stores/authStore';
import { translations } from '../i18n/translations';

export function useTranslation() {
  const { appLanguage } = useAuthStore();
  
  const t = (key: string): string => {
    return translations[appLanguage]?.[key] || translations['en'][key] || key;
  };
  
  return { t };
}