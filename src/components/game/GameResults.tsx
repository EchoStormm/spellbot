import React from 'react';
import { Check, X } from 'lucide-react';
import { useTranslation } from '../../hooks/useTranslation';

interface GameResult {
  word: string;
  correct: boolean;
  userInput: string;
}

interface GameResultsProps {
  results: GameResult[];
  correctCount: number;
  totalCount: number;
  averageTime: number;
  onPlayAgain: () => void;
}

export function GameResults({
  results,
  correctCount,
  totalCount,
  averageTime,
  onPlayAgain
}: GameResultsProps) {
  const accuracy = (correctCount / totalCount) * 100;
  const { t } = useTranslation();

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="text-center mb-8">
          <h2 className="text-2xl font-bold">{t('game.complete.title')}</h2>
          <p className="text-gray-600 mt-2">
            {t('game.complete.score')
              .replace('{correct}', correctCount.toString())
              .replace('{total}', totalCount.toString())
              .replace('{accuracy}', accuracy.toFixed(1))
            }
          </p>
        </div>
        
        <div className="space-y-4">
          {results.map((result, index) => (
            <div 
              key={index}
              className={`grid grid-cols-2 gap-4 p-4 rounded-lg ${
                result.correct ? 'bg-green-50' : 'bg-red-50'
              }`}
            >
              <div className="flex items-center gap-3">
                <div className={`p-1 rounded-full ${result.correct ? 'bg-green-100' : 'bg-red-100'}`}>
                  {result.correct ? (
                    <Check className="w-4 h-4 text-green-600" />
                  ) : (
                    <X className="w-4 h-4 text-red-600" />
                  )}
                </div>
                <div>
                  <p className="font-medium text-gray-900">{t('game.complete.expected')}</p>
                  <p className="text-gray-700">{result.word}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div>
                  <p className="font-medium text-gray-900">{t('game.complete.yourAnswer')}</p>
                  <p className={result.correct ? 'text-gray-700' : 'text-red-600'}>
                    {result.userInput}
                  </p>
                </div>
              </div>
            </div>
          ))}
        </div>
        
        <div className="mt-6 text-sm text-gray-500 text-center">
          {t('game.complete.avgTime').replace('{time}', (averageTime / 1000).toFixed(2))}
        </div>

        <button
          onClick={onPlayAgain}
          className="mt-6 w-full py-3 px-4 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 font-medium"
        >
          {t('game.complete.playAgain')}
        </button>
      </div>
    </div>
  );
}