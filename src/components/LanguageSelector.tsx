import React from 'react';
import { useAuthStore } from '../stores/authStore';
import { APP_LANGUAGES, type AppLanguage } from '../types/user';

const FLAGS = {
  fr: "🇫🇷",
  en: "🇬🇧",
  de: "🇩🇪"
};

export default function LanguageSelector() {
  const { appLanguage, updateSettings, isAuthenticated } = useAuthStore();

  const handleLanguageChange = async (lang: AppLanguage) => {
    if (isAuthenticated) {
      await updateSettings({ appLanguage: lang });
    } else {
      // If not authenticated, just update the local state
      useAuthStore.setState(state => ({ ...state, appLanguage: lang }));
    }
  };

  return (
    <div className="absolute top-4 right-4">
      <select
        value={appLanguage}
        onChange={(e) => handleLanguageChange(e.target.value as AppLanguage)}
        className="appearance-none bg-white/10 text-white rounded-lg pl-8 pr-8 py-2 cursor-pointer hover:bg-white/20 transition-colors"
        style={{ textAlignLast: 'center' }}
      >
        {APP_LANGUAGES.map(lang => (
          <option 
            key={lang.value} 
            value={lang.value}
            className="text-gray-900"
          >
            {FLAGS[lang.value as keyof typeof FLAGS]} {lang.label}
          </option>
        ))}
      </select>
    </div>
  );
}