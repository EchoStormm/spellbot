import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Play, Pause, Volume2, ChevronRight, Languages } from 'lucide-react';
import { useTranslation } from '../hooks/useTranslation';
import { supabase } from '../lib/supabase';
import { useAuthStore } from '../stores/authStore';
import { GameMode, Language, SUPPORTED_LANGUAGES } from '../types/game';
import { generateSpeech } from '../services/openai';
import type { Voice } from '../types/openai';

/**
 * NewGame component handles the creation of new game sessions
 * It supports two modes:
 * 1. Custom mode: Users can input their own list of words
 * 2. Spaced Repetition mode: Uses the SM-2 algorithm for optimized learning
 * 
 * The component manages:
 * - Word validation and deduplication
 * - Database integration for word storage
 * - Spaced repetition progress tracking
 * - Language selection
 */
function NewGame() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const { defaultLanguage } = useAuthStore();
  const [gameMode, setGameMode] = useState<GameMode>('custom');
  const [language, setLanguage] = useState<string>(defaultLanguage);
  const [customWords, setCustomWords] = useState<string>('');
  const [error, setError] = useState<string>('');
  const [isCreatingSession, setIsCreatingSession] = useState(false);
  const [wordErrors, setWordErrors] = useState<string[]>([]);
  const user = useAuthStore(state => state.user);

  /**
   * Handles form submission for both game modes
   * For custom mode:
   * - Validates word count and uniqueness
   * - Stores words in database
   * - Initializes spaced repetition progress
   * 
   * For spaced repetition mode:
   * - Fetches due words based on SM-2 algorithm
   * - Prepares review session
   */
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsCreatingSession(true);

    try {
      let sessionId: string | null = null;

      if (gameMode === 'custom') {
        const words = customWords
          .split('\n')
          .map(word => word.trim().toLowerCase())
          .filter(word => word.length > 0);

        if (words.length !== 10) {
          setError(t('game.error.wordCount'));
          return;
        }

        // Validate each word
        const errors: string[] = [];
        const validWordPattern = /^[a-zA-ZÀ-ÿ]+[-''a-zA-ZÀ-ÿ]*[a-zA-ZÀ-ÿ]+$/;
        
        words.forEach((word, index) => {
          if (!validWordPattern.test(word)) {
            errors.push(`${t('game.error.invalidChars')} (${word})`);
          }
        });

        if (errors.length > 0) {
          setWordErrors(errors);
          return;
        }

        // Remove duplicates
        const uniqueWords = [...new Set(words)];
        if (uniqueWords.length !== words.length) {
          setError(t('game.error.duplicateWords'));
          return;
        }

        try {
          // Insert words into database if they don't exist
          const { data: existingWords, error: fetchError } = await supabase
            .from('words')
            .select('word_id, text')
            .in('text', uniqueWords)
            .eq('language', language);

          if (fetchError) throw fetchError;

          const existingTexts = new Set(existingWords?.map(w => w.text) || []);
          const newWords = uniqueWords.filter(word => !existingTexts.has(word));

          if (newWords.length > 0) {
            const { error: insertError } = await supabase
              .from('words')
              .insert(newWords.map(text => ({
                text,
                language
              })));

            if (insertError) throw insertError;
          }

          // Get all word IDs (both existing and newly inserted)
          const { data: allWords, error: getAllError } = await supabase
            .from('words')
            .select('word_id, text')
            .in('text', uniqueWords)
            .eq('language', language);

          if (getAllError) throw getAllError;

          // Add words to spaced repetition system
          const { error: progressError } = await supabase
            .from('spaced_repetition_progress')
            .upsert(
              allWords?.map(word => ({
                user_id: useAuthStore.getState().user?.id,
                word_id: word.word_id,
                next_review: new Date().toISOString()
              })) || [],
              { onConflict: 'user_id,word_id' }
            );

          if (progressError) throw progressError;
        } catch (err) {
          console.error('Error saving words:', err);
          // Continue with the game even if there's an error saving to database
        }

        // Create new game session
        const { data: sessionData, error: sessionError } = await supabase
          .from('game_sessions')
          .insert({
            user_id: user?.id,
            game_mode: gameMode,
            language,
            total_words: uniqueWords.length
          })
          .select()
          .single();

        if (sessionError) {
          console.error('Error creating game session:', sessionError);
          setError('Failed to create game session');
          setIsCreatingSession(false);
          return;
        }

        sessionId = sessionData.session_id;

        navigate('/game-play', { 
          state: { 
            mode: gameMode,
            language,
            words: uniqueWords,
            sessionId
          }
        });
      } else {
        // Get words due for review
        const { data: dueWords, error: dueError } = await supabase
          .from('spaced_repetition_progress')
          .select('*, words!inner(*)')
          .eq('user_id', useAuthStore.getState().user?.id)
          .eq('words.language', language)
          .lte('next_review', new Date().toISOString())
          .order('next_review', { ascending: true })
          .order('interval', { ascending: true })
          .limit(10);

        if (dueError) throw dueError;

        const words = dueWords?.map(w => w.words.text).filter(Boolean) || [];

        if (words.length === 0) {
          setError('No words due for review. Try adding some words first!');
          return;
        }

        // Create new game session for spaced repetition mode
        const { data: sessionData, error: sessionError } = await supabase
          .from('game_sessions')
          .insert({
            user_id: user?.id,
            game_mode: gameMode,
            language,
            total_words: words.length
          })
          .select()
          .single();

        if (sessionError) {
          console.error('Error creating game session:', sessionError);
          setError('Failed to create game session');
          setIsCreatingSession(false);
          return;
        }

        navigate('/game-play', {
          state: {
            mode: gameMode,
            language,
            words,
            sessionId: sessionData.session_id
          }
        });
      }
    } catch (err) {
      console.error('Error creating game:', err);
      setError('Failed to create game');
    } finally {
      setIsCreatingSession(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-3xl font-bold text-gray-900 mb-6">{t('game.newGame')}</h1>
      
      <form onSubmit={handleSubmit} className="bg-white rounded-lg shadow p-6 space-y-6">
        {/* Language Selection */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            {t('game.language')}
          </label>
          <div className="relative">
            <select
              value={language}
              onChange={(e) => setLanguage(e.target.value)}
              className="block w-full rounded-md border border-gray-300 py-2 pl-3 pr-10 text-base focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
            >
              {SUPPORTED_LANGUAGES.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {t(`language.${lang.code}`)}
                </option>
              ))}
            </select>
            <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-500">
              <Languages size={20} />
            </div>
          </div>
        </div>

        {/* Game Mode Selection */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            {t('game.mode')}
          </label>
          <div className="grid grid-cols-2 gap-4">
            <button
              type="button"
              onClick={() => setGameMode('custom')}
              className={`p-4 rounded-lg border-2 text-left ${
                gameMode === 'custom'
                  ? 'border-indigo-500 bg-indigo-50'
                  : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <h3 className="font-medium">{t('game.mode.custom')}</h3>
              <p className="text-sm text-gray-500">
                {t('game.mode.customDesc')}
              </p>
            </button>
            <button
              type="button"
              onClick={() => setGameMode('spaced-repetition')}
              className={`p-4 rounded-lg border-2 text-left ${
                gameMode === 'spaced-repetition'
                  ? 'border-indigo-500 bg-indigo-50'
                  : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <h3 className="font-medium">{t('game.mode.spaced')}</h3>
              <p className="text-sm text-gray-500">
                {t('game.mode.spacedDesc')}
              </p>
            </button>
          </div>
        </div>

        {/* Custom Words Input */}
        {gameMode === 'custom' && (
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              {t('game.enterWords')}
            </label>
            <textarea
              value={customWords}
              onChange={(e) => {
                const lines = e.target.value.split('\n');
                const capitalizedLines = lines.map(line => {
                  if (line.length === 0) return line;
                  return line.charAt(0).toUpperCase() + line.slice(1);
                });
                setCustomWords(capitalizedLines.join('\n'));
              }}
              rows={10}
              className="block w-full rounded-md border border-gray-300 py-2 px-3 text-base focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              placeholder={t('game.enterWordsPlaceholder')}
            />
            {error && (
              <p className="mt-2 text-sm text-red-600 mb-2">
                {error}
              </p>
            )}
            {wordErrors.length > 0 && (
              <div className="mt-2 text-sm text-red-600 space-y-1">
                {wordErrors.map((err, index) => (
                  <p key={index}>{err}</p>
                ))}
              </div>
            )}
            <p className="mt-2 text-sm text-gray-500">
              {t('game.note')}
            </p>
          </div>
        )}

        {/* Submit Button */}
        <div>
          <button
            type="submit"
            disabled={isCreatingSession}
            className="w-full flex items-center justify-center gap-2 py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            {isCreatingSession ? (
              <>
                <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent" />
                Creating game...
              </>
            ) : (
              <>
                <Play size={20} />
                {t('game.start')}
              </>
            )}
          </button>
        </div>
      </form>
    </div>
  );
}

export default NewGame;