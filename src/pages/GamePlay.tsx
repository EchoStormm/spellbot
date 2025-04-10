import React, { useState, useEffect, useRef } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { tts } from '../services/tts';
import { supabase } from '../lib/supabase';
import { useAuthStore } from '../stores/authStore';
import { useTranslation } from '../hooks/useTranslation';
import { GameTimer } from '../components/game/GameTimer';
import { GameInput } from '../components/game/GameInput';
import { GameResults } from '../components/game/GameResults';

/**
 * GamePlay Component Documentation
 * 
 * Purpose:
 * Implements a language learning game with two modes:
 * 1. Custom Practice: User-defined word lists
 * 2. Spaced Repetition: Algorithmic learning system
 * 
 * Key Features:
 * - Text-to-speech word pronunciation
 * - Real-time input validation
 * - Response time tracking
 * - Progress persistence
 * - Statistics tracking
 * - Spaced repetition algorithm (SM-2)
 * 
 * Data Flow:
 * 1. Word Loading -> TTS -> User Input -> Validation -> Next Word
 * 2. Session tracking and statistics updates
 * 3. Spaced repetition calculations (when applicable)
 * 
 * State Management:
 * - Game progression (current word, results)
 * - Audio playback (TTS states)
 * - Timer and pause functionality
 * - User input and validation
 * - Session and statistics tracking
 */

/**
 * Interface for managing the game's internal state
 * 
 * @property currentWordIndex - Current position in word list
 * @property userInput - User's typed response
 * @property isPaused - Game pause status
 * @property results - Array of attempt results
 * @property isComplete - Game completion status
 * @property timeRemaining - Countdown timer value
 * @property isPlaying - TTS playback status
 * @property isLoading - Async operation status
 * @property currentWord - Active word being tested
 * @property timerPaused - Timer pause status
 */
interface GameStateManagement {
  currentWordIndex: number;      // Index of current word in the game
  userInput: string;            // Current user input text
  isPaused: boolean;           // Game pause state
  results: Array<{            // Array of word attempt results
    word: string;
    correct: boolean;
    userInput: string;
  }>;
  isComplete: boolean;       // Whether game is finished
  timeRemaining: number;    // Seconds left for current word
  isPlaying: boolean;      // Whether TTS is currently playing
  isLoading: boolean;     // Loading state for async operations
  currentWord: string;   // Current word being tested
  timerPaused: boolean; // Timer pause state
}

/**
 * GameState interface defining the structure of the game configuration
 * 
 * @property mode - Game mode selection
 *                 'custom': User-provided word list
 *                 'spaced-repetition': Algorithmic learning
 * @property language - Target language code (e.g., 'en', 'fr', 'de')
 * @property words - Word list for the session
 */
interface GameState {
  mode: 'custom' | 'spaced-repetition';
  language: string;
  sessionId: string;
  words?: string[];
}

/**
 * GamePlay component handles the main game logic for both custom and spaced repetition modes.
 */
function GamePlay() {
  const location = useLocation();
  const navigate = useNavigate();
  const gameState = location.state as GameState;
  const isHandlingNextWord = useRef(false);
  const isUpdatingSession = useRef(false);
  const isUpdatingProgress = useRef(false);
  
  const [currentWordIndex, setCurrentWordIndex] = useState(0);
  const [userInput, setUserInput] = useState('');
  const [isPaused, setIsPaused] = useState(false);
  const [results, setResults] = useState<Array<{
    word: string;
    correct: boolean;
    userInput: string;
  }>>([]);
  const [isComplete, setIsComplete] = useState(false);
  const [timeRemaining, setTimeRemaining] = useState<number>(10);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [currentWord, setCurrentWord] = useState<string>('');
  const [isTimerActive, setIsTimerActive] = useState(false);
  const [timerPaused, setTimerPaused] = useState(false);
  const [wordIds, setWordIds] = useState<string[]>([]);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [startTime, setStartTime] = useState<number | null>(null);
  const [responseTimes, setResponseTimes] = useState<number[]>([]);
  const [isInitialized, setIsInitialized] = useState(false);
  const [inputError, setInputError] = useState<string | null>(null);
  const [shouldPlayNextWord, setShouldPlayNextWord] = useState(false);
  const [pendingAttempts, setPendingAttempts] = useState<Array<{
    session_id: string;
    word_id: string;
    user_id: string;
    user_input: string;
    is_correct: boolean;
    response_time_ms: number;
  }>>([]);

  const user = useAuthStore(state => state.user);
  const { t } = useTranslation();

  const triggerTTS = async (word: string) => {
    if (!gameState?.words || timerPaused || !word) return;
    
    const inputRef = document.querySelector('input[type="text"]') as HTMLInputElement;
    if (inputRef) {
      inputRef.blur();
    }
    
    console.log(`TTS: Starting playback for "${word}" in ${gameState.language}`);
    setTimeRemaining(10);

    try {
      await tts.speak(word, gameState.language, {
        onStart: () => setIsPlaying(true),
        onEnd: () => {
          setTimeout(() => {
            const inputElement = document.querySelector('input[type="text"]') as HTMLInputElement;
            if (inputElement) {
              inputElement.focus();
              const len = inputElement.value.length;
              inputElement.setSelectionRange(len, len);
            }
          }, 100);
          setIsPlaying(false);
          setStartTime(Date.now());
          setIsLoading(false);
        },
        onError: (error) => {
          console.error(`TTS: Playback error for "${word}":`, error);
          setIsPlaying(false);
          setStartTime(Date.now());
          setIsLoading(false);
        }
      });
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      console.error(`TTS: Failed to initialize playback for "${word}":`, errorMessage);
      setIsPlaying(false);
      setIsLoading(false);
    }
  };

  const validateInput = (input: string): boolean => {
    setInputError(null);
    
    if (input.length > 50) {
      setInputError(t('game.error.tooLong'));
      return false;
    }
    
    return true;
  };

  const handleKeyDown = async (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && !isPlaying && !isLoading && !isComplete) {
      e.preventDefault();
      if (userInput.trim() && validateInput(userInput.trim())) {
        await handleNextWord();
      }
    }
  };

  const resetGame = async () => {
    setIsLoading(true);
    
    if (!gameState?.words?.length) {
      setIsLoading(false);
      navigate('/new-game');
      return;
    }

    try {
      setSessionId(gameState.sessionId);
      setCurrentWordIndex(0);
      setUserInput('');
      setIsPaused(false);
      setResults([]);
      setIsComplete(false);
      setTimeRemaining(10);
      setIsPlaying(false);
      setIsInitialized(false);
      setPendingAttempts([]);
      isHandlingNextWord.current = false;
      isUpdatingSession.current = false;
      isUpdatingProgress.current = false;

      setStartTime(null);
      setResponseTimes([]);

      const { data: existingWords, error: fetchError } = await supabase
        .from('words')
        .select('word_id, text')
        .in('text', gameState.words)
        .eq('language', gameState.language);

      if (fetchError) {
        console.error('Error fetching word IDs:', fetchError);
        return;
      }

      const existingWordsMap = new Map(
        existingWords?.map(w => [w.text.toLowerCase(), w.word_id]) || []
      );

      const wordsToInsert = gameState.words.filter(
        word => !existingWordsMap.has(word.toLowerCase())
      ).map(word => ({
        text: word,
        language: gameState.language
      }));

      if (wordsToInsert.length > 0) {
        const { data: insertedData, error: insertError } = await supabase
          .from('words')
          .insert(wordsToInsert)
          .select('word_id, text');

        if (insertError) {
          console.error('Error inserting words:', insertError);
          return;
        }

        insertedData?.forEach(w => {
          existingWordsMap.set(w.text.toLowerCase(), w.word_id);
        });
      }

      const finalWordIds = gameState.words.map(word => 
        existingWordsMap.get(word.toLowerCase())
      ).filter((id): id is string => id !== undefined);

      if (finalWordIds.length !== gameState.words.length) {
        console.error('Some words could not be mapped to IDs');
        return;
      }

      setWordIds(finalWordIds);
      setCurrentWord(gameState.words[0]);
      setIsInitialized(true);
      setIsLoading(false);

    } catch (error) {
      console.error('Error in resetGame:', error);
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (!gameState?.words && gameState?.mode === 'custom') {
      navigate('/new-game');
      return;
    }
    
    resetGame();
    setShouldPlayNextWord(true);

    return () => {
      tts.stop();
    };
  }, [gameState, navigate]);

  useEffect(() => {
    let timer: NodeJS.Timeout;
    
    const shouldRunTimer = 
      !timerPaused && 
      !isComplete && 
      !isPlaying && 
      !isLoading && 
      isInitialized &&
      isTimerActive;
    
    if (shouldRunTimer) {
      console.log(`Timer: Active for word "${currentWord}" (${timeRemaining}s remaining)`);
      
      timer = setInterval(() => {
        setTimeRemaining(prev => Math.max(0, prev - 0.05));
      }, 50);
      
      return () => {
        clearInterval(timer);
        console.log(`Timer: Stopped for word "${currentWord}"`);
      };
    }
  }, [timerPaused, isComplete, isPlaying, isLoading, isInitialized, isTimerActive, currentWord]);

  useEffect(() => {
    if (timeRemaining <= 0 && isTimerActive && !isComplete) {
      console.log(`Timer: Expired for word "${currentWord}"`);
      if (timerPaused) return;
      setIsTimerActive(false);
      setUserInput('');
      handleNextWord();
    }
  }, [timeRemaining, isTimerActive, currentWord, timerPaused, isComplete]);

  useEffect(() => {
    if (!isComplete) {
      setTimeRemaining(10);
      setIsTimerActive(true);
      console.log(`Timer: Reset to 10s for word "${currentWord}"`);
    }
  }, [currentWordIndex, isPaused, isComplete]);

  useEffect(() => {
    if (shouldPlayNextWord && currentWord && !timerPaused && !isComplete) {
      console.log('TTS: Auto-playing next word');
      setShouldPlayNextWord(false);
      triggerTTS(currentWord);
    }
  }, [shouldPlayNextWord, currentWord, timerPaused, isComplete]);

  const updateSpacedRepetitionProgress = async (
    wordId: string,
    isCorrect: boolean,
    currentProgress: any
  ) => {
    if (isUpdatingProgress.current) return;
    isUpdatingProgress.current = true;

    try {
      const quality = isCorrect ? 5 : 0;
      let { easiness_factor, interval, repetitions } = currentProgress;
      
      if (quality >= 3) {
        if (repetitions === 0) interval = 1;
        else if (repetitions === 1) interval = 6;
        else interval = Math.round(interval * easiness_factor);
        
        repetitions += 1;
      } else {
        repetitions = 0;
        interval = 1;
      }
      
      easiness_factor = Math.max(
        1.3,
        easiness_factor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
      );

      const next_review = new Date();
      next_review.setDate(next_review.getDate() + interval);

      await supabase
        .from('spaced_repetition_progress')
        .update({
          easiness_factor,
          interval,
          repetitions,
          next_review: next_review.toISOString(),
          last_review: new Date().toISOString()
        })
        .eq('user_id', user?.id)
        .eq('word_id', wordId);
    } finally {
      isUpdatingProgress.current = false;
    }
  };

  const completeGame = async (newResults: typeof results, newResponseTimes: number[]) => {
    if (isUpdatingSession.current || !sessionId) return;
    
    isUpdatingSession.current = true;

    try {
      const avgResponseTime = newResponseTimes.reduce((a, b) => a + b, 0) / newResponseTimes.length;
      const correctCount = newResults.filter(r => r.correct).length;

      await supabase
        .from('game_sessions')
        .update({
          end_time: new Date().toISOString(),
          completed: true,
          correct_words: correctCount,
          average_response_time: avgResponseTime
        })
        .eq('session_id', sessionId)
        .eq('user_id', user?.id);

    } catch (error) {
      console.error('Error completing game session:', error);
    } finally {
      isUpdatingSession.current = false;
    }
  };

  const handleNextWord = async () => {
    if (isHandlingNextWord.current || isPlaying || isLoading || timerPaused) return;
    
    try {
      isHandlingNextWord.current = true;
      
      if (userInput.trim() && userInput.trim().length > 50) {
        setInputError(t('game.error.tooLong'));
        return;
      }
      
      setIsLoading(true);
      const responseTime = startTime ? Date.now() - startTime : 0;
      const isCorrect = currentWord.toLowerCase().trim() === userInput.trim().toLowerCase();
      
      const newResult = { 
        word: currentWord,
        correct: isCorrect,
        userInput: userInput.trim() || t('dashboard.noAnswer')
      };
      const newResults = [...results, newResult];
      
      const newResponseTimes = [...responseTimes, responseTime];
      const currentWordId = wordIds[currentWordIndex];
      
      // Save the attempt first
      if (sessionId && currentWordId && !isComplete) {
        await supabase
          .from('word_attempts')
          .insert({
            session_id: sessionId,
            word_id: currentWordId,
            user_id: user?.id,
            user_input: userInput.trim() || '',
            is_correct: isCorrect,
            response_time_ms: responseTime
          });
          
        // Update spaced repetition progress if needed
        if (gameState.mode === 'spaced-repetition') {
          const { data: currentProgress } = await supabase
            .from('spaced_repetition_progress')
            .select('*')
            .eq('user_id', user?.id)
            .eq('word_id', currentWordId)
            .single();

          if (currentProgress) {
            await updateSpacedRepetitionProgress(currentWordId, isCorrect, currentProgress);
          }
        }
      }
      
      setResults(newResults);
      setResponseTimes(newResponseTimes);
      setUserInput('');
      setStartTime(null);
      
      // Check if this was the last word
      const isLastWord = currentWordIndex + 1 >= (gameState.words?.length || 0);
      
      if (isLastWord) {
        await completeGame(newResults, newResponseTimes);
        setIsComplete(true);
      } else {
        const nextIndex = currentWordIndex + 1;
        setCurrentWordIndex(nextIndex);
        setCurrentWord(gameState.words[nextIndex]);
        setShouldPlayNextWord(true);
      }
    } finally {
      setIsLoading(false);
      isHandlingNextWord.current = false;
    }
  };

  if (isComplete) {
    const correctCount = results.filter(r => r.correct).length;
    const avgResponseTime = responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length;
    
    return (
      <GameResults
        results={results}
        correctCount={correctCount}
        totalCount={results.length}
        averageTime={avgResponseTime}
        onPlayAgain={resetGame}
      />
    );
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="text-lg font-medium">
            {t('game.wordProgress').replace('{current}', String(currentWordIndex + 1)).replace('{total}', String(gameState.words?.length))}
          </div>
        </div>

        <GameTimer
          timeRemaining={timeRemaining}
          timerPaused={timerPaused}
          isPlaying={isPlaying}
          isLoading={isLoading}
          currentWord={currentWord}
          onPause={() => {
            setTimerPaused(!timerPaused);
            setIsTimerActive(true);
            if (isPlaying) {
              console.log('TTS: Stopping playback due to pause');
              tts.stop();
              setIsPlaying(false);
            }
          }}
          onPlayWord={() => triggerTTS(currentWord)}
          disabled={!gameState.words?.[currentWordIndex]}
        />

        <GameInput
          value={userInput}
          error={inputError}
          disabled={timerPaused}
          isInitialized={isInitialized}
          isPlaying={isPlaying}
          hasStartTime={!!startTime}
          onKeyDown={handleKeyDown}
          onChange={(e) => {
            if (!startTime) return;
            setUserInput(e.target.value);
            setInputError(null);
          }}
          onSubmit={handleNextWord}
        />
      </div>
    </div>
  );
}

export default GamePlay;