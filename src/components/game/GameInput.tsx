import React from 'react';
import { ChevronRight } from 'lucide-react';
import { useTranslation } from '../../hooks/useTranslation';

interface GameInputProps {
  value: string;
  error?: string | null;
  disabled?: boolean;
  isInitialized: boolean;
  isPlaying: boolean;
  hasStartTime: boolean;
  onKeyDown: (e: React.KeyboardEvent<HTMLInputElement>) => void;
  onChange: (e: React.ChangeEvent<HTMLInputElement>) => void;
  onSubmit: () => void;
}

export function GameInput({
  value,
  error,
  disabled,
  isInitialized,
  isPlaying,
  hasStartTime,
  onKeyDown,
  onChange,
  onSubmit
}: GameInputProps) {
  const { t } = useTranslation();

  return (
    <div className="space-y-4">
      <input
        type="text"
        value={value}
        onKeyDown={onKeyDown}
        onChange={onChange}
        maxLength={50}
        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
        disabled={disabled || !isInitialized || !hasStartTime || isPlaying}
        placeholder={
          !isInitialized ? t('game.loading') :
          isPlaying ? t('game.listening') :
          !hasStartTime ? t('game.listenFirst') :
          t('game.typeWord')
        }
      />
      {error && (
        <p className="text-red-500 text-sm">{error}</p>
      )}
      <button
        onClick={onSubmit}
        disabled={disabled || isPlaying || !value.trim() || !!error}
        className="w-full flex items-center justify-center gap-2 py-2 px-4 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        <ChevronRight className="w-5 h-5" />
        {t('game.nextWord')}
      </button>
    </div>
  );
}