import React from 'react';
import { Play, Pause, Volume2 } from 'lucide-react';

interface GameTimerProps {
  timeRemaining: number;
  timerPaused: boolean;
  isPlaying: boolean;
  isLoading: boolean;
  currentWord: string;
  onPause: () => void;
  onPlayWord: () => void;
  disabled?: boolean;
}

export function GameTimer({
  timeRemaining,
  timerPaused,
  isPlaying,
  isLoading,
  currentWord,
  onPause,
  onPlayWord,
  disabled
}: GameTimerProps) {
  return (
    <div className="mb-8">
      <div className="flex items-center justify-center gap-4 mb-4">
        <button
          onClick={onPause}
          className="p-2 rounded-full hover:bg-gray-100"
        >
          {timerPaused ? <Play size={24} /> : <Pause size={24} />}
        </button>
        
        <div className="w-24 h-24 rounded-full bg-indigo-100 flex items-center justify-center">
          <div className="font-mono text-4xl font-bold text-indigo-600">
            {Math.ceil(timeRemaining)}
          </div>
        </div>

        <div className="relative">
          <button
            onClick={onPlayWord}
            className={`p-2 rounded-full ${!isPlaying && !isLoading && !timerPaused ? 'hover:bg-gray-100' : ''}`}
            disabled={isPlaying || isLoading || !currentWord || timerPaused || disabled}
          >
            <Volume2 size={24} className={
              isPlaying || isLoading ? 'text-gray-400 animate-pulse' : 
              timerPaused ? 'text-gray-400' : ''
            } />
          </button>
          {(isPlaying || isLoading) && (
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="w-full h-full rounded-full border-2 border-indigo-600 border-t-transparent animate-spin" />
            </div>
          )}
        </div>
      </div>

      <div className={`h-2 bg-gray-200 rounded-full overflow-hidden relative ${timerPaused ? 'opacity-50' : ''}`}>
        <div 
          className="h-full bg-indigo-500 absolute left-0 top-0 transition-all duration-100 ease-linear"
          style={{ width: `${((timeRemaining / 10) * 100).toString()}%` }}
        />
      </div>
    </div>
  );
}