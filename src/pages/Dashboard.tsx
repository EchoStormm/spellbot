import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useLocation } from 'react-router-dom';
import { Trophy, Users, Clock, Star, Brain, Calendar, Award, Timer, Book } from 'lucide-react';
import { useAuthStore } from '../stores/authStore';
import { supabase } from '../lib/supabase';
import { useTranslation } from '../hooks/useTranslation';

interface WordAttempt {
  word_id: string;
  user_input: string;
  is_correct: boolean;
  response_time_ms: number;
  words: {
    text: string;
  };
}

interface GameSession {
  session_id: string;
  game_mode: string;
  language: string;
  correct_words: number;
  total_words: number;
  average_response_time: number;
  created_at: string;
  completed: boolean;
}

interface StatCard {
  icon: any;
  title: string;
  value: string | number;
  color: string;
  subtext?: string;
}

function StatCard({ icon: Icon, title, value, color, subtext }: StatCard) {
  return (
    <div className={`bg-white rounded-lg shadow p-6 flex items-center gap-4 ${color}`}>
      <div className="p-3 rounded-full bg-opacity-10">
        <Icon size={24} />
      </div>
      <div>
        <h3 className="text-sm font-medium text-gray-500">{title}</h3>
        <p className="text-2xl font-semibold mb-1">{value}</p>
        {subtext && <p className="text-sm text-gray-500">{subtext}</p>}
      </div>
    </div>
  );
}

interface Statistics {
  daily: {
    total_sessions: number;
    total_words_attempted: number;
    total_words_correct: number;
    average_response_time: number;
    total_time_spent: string;
  };
  achievements: Array<{
    name: string;
    description: string;
    translations: Array<{
      language_code: string;
      name: string;
      description: string;
    }>;
    icon_name: string;
    achieved_at: string;
  }>;
  recentGames: Array<{
    session_id: string;
    game_mode: string;
    language: string;
    correct_words: number;
    total_words: number;
    average_response_time: number;
    created_at: string;
  }>;
}

function Dashboard() {
  const { t } = useTranslation();
  const location = useLocation();
  const { user, appLanguage } = useAuthStore();
  const [selectedSession, setSelectedSession] = useState<string | null>(null);
  const [wordAttempts, setWordAttempts] = useState<WordAttempt[]>([]);
  const [loadingAttempts, setLoadingAttempts] = useState(false);
  const [stats, setStats] = useState<Statistics | null>(null);
  const [loading, setLoading] = useState(true);
  const lastVisitRef = useRef<number>(Date.now());

  const fetchWordAttempts = async (sessionId: string) => {
    setLoadingAttempts(true);
    try {
      const { data, error } = await supabase
        .from('word_attempts')
        .select(`
          word_id,
          user_input,
          is_correct,
          response_time_ms,
          words (
            text
          )
        `)
        .eq('session_id', sessionId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setWordAttempts(data || []);
    } catch (err) {
      console.error('Error fetching word attempts:', err);
    } finally {
      setLoadingAttempts(false);
    }
  };

  const handleSessionClick = (sessionId: string) => {
    if (selectedSession === sessionId) {
      setSelectedSession(null);
      setWordAttempts([]);
    } else {
      setSelectedSession(sessionId);
      fetchWordAttempts(sessionId);
    }
  };

  const fetchStatistics = useCallback(async () => {
    try {
      const today = new Date().toISOString().split('T')[0];

      // Fetch daily statistics
      const { data: dailyStats } = await supabase
        .from('user_statistics')
        .select('*')
        .eq('user_id', user?.id)
        .eq('period_start', today)
        .eq('period_type', 'daily')
        .maybeSingle();

      // Fetch achievements
      const { data: achievements } = await supabase
        .from('user_achievements')
        .select(`
          achievements!inner (
            name,
            description,
            icon_name,
            achievement_translations (
              language_code,
              name,
              description
            )
          ),
          achieved_at
        `)
        .eq('user_id', user?.id)
        .order('achieved_at', { ascending: false });

      // Fetch recent games
      const { data: recentGames } = await supabase
        .from('game_sessions')
        .select('*')
        .eq('user_id', user?.id)
        .order('created_at', { ascending: false })
        .limit(10);

      setStats({
        daily: dailyStats || {
          total_sessions: 0,
          total_words_attempted: 0,
          total_words_correct: 0,
          average_response_time: 0,
          total_time_spent: '00:00:00'
        },
        achievements: achievements?.map(a => ({
          name: a.achievements.achievement_translations.find(t => t.language_code === appLanguage)?.name || a.achievements.name,
          description: a.achievements.achievement_translations.find(t => t.language_code === appLanguage)?.description || a.achievements.description,
          translations: a.achievements.achievement_translations,
          icon_name: a.achievements.icon_name,
          achieved_at: a.achieved_at
        })) || [],
        recentGames: recentGames || []
      });
    } catch (error) {
      console.error('Error fetching statistics:', error);
    } finally {
      setLoading(false);
    }
  }, [user?.id, appLanguage]);

  // Initial fetch
  useEffect(() => {
    if (user?.id) {
      fetchStatistics();
    }
  }, [user?.id, fetchStatistics]);

  // Refresh when returning to dashboard
  useEffect(() => {
    const now = Date.now();
    // Only refresh if more than 5 seconds have passed since last visit
    if (now - lastVisitRef.current > 5000) {
      fetchStatistics();
    }
    lastVisitRef.current = now;
  }, [location.key]);

  // Set up real-time subscription for game sessions
  useEffect(() => {
    if (!user?.id) return;

    const subscription = supabase
      .channel('game_sessions_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'game_sessions',
          filter: `user_id=eq.${user.id}`
        },
        () => {
          fetchStatistics();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [user?.id, fetchStatistics]);

  // Set up real-time subscription for user statistics
  useEffect(() => {
    if (!user?.id) return;

    const subscription = supabase
      .channel('user_statistics_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_statistics',
          filter: `user_id=eq.${user.id}`
        },
        () => {
          fetchStatistics();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [user?.id, fetchStatistics]);

  // Set up real-time subscription for achievements
  useEffect(() => {
    if (!user?.id) return;

    const subscription = supabase
      .channel('user_achievements_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_achievements',
          filter: `user_id=eq.${user.id}`
        },
        () => {
          fetchStatistics();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [user?.id, fetchStatistics]);

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">{t('dashboard.title')}</h1>
      
      {/* Today's Statistics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <StatCard 
          icon={Brain}
          title={t('dashboard.wordsLearned')}
          value={stats?.daily.total_words_correct || 0}
          color="text-indigo-600"
          subtext={`${((stats?.daily.total_words_correct || 0) / (stats?.daily.total_words_attempted || 1) * 100).toFixed(1)}% ${t('dashboard.accuracy')}`}
        />
        <StatCard 
          icon={Users}
          title={t('dashboard.sessionsToday')}
          value={stats?.daily.total_sessions || 0}
          color="text-blue-600"
        />
        <StatCard 
          icon={Clock}
          title={t('dashboard.timeSpent')}
          value={stats?.daily.total_time_spent?.split('.')[0] || '0:00:00'}
          color="text-purple-600"
        />
        <StatCard 
          icon={Timer}
          title={t('dashboard.avgResponseTime')}
          value={`${((stats?.daily.average_response_time || 0) / 1000).toFixed(1)}s ${t('dashboard.avg')}`}
          color="text-orange-600"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Games */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">{t('dashboard.recentGames')}</h2>
          <div className="divide-y divide-gray-100">
            {stats?.recentGames.map((game) => (
              <div key={game.session_id}>
                <button
                  onClick={() => handleSessionClick(game.session_id)}
                  disabled={!game.completed}
                  className="w-full text-left"
                >
                  <div className={`flex items-center justify-between p-4 ${
                    game.completed ? 'hover:bg-gray-50 cursor-pointer' : 'opacity-50 cursor-not-allowed'
                  } transition-colors`}>
                    <div className="flex items-center gap-4">
                      <div className="relative">
                        <div className={`w-2 h-2 rounded-full ${
                          !game.completed ? 'bg-red-500' :
                          (game.correct_words || 0) === game.total_words ? 'bg-green-500' : 'bg-yellow-500'
                        }`} />
                        {!game.completed && (
                          <div className="absolute -top-1 -right-1 w-3 h-3 animate-ping rounded-full bg-red-400 opacity-75" />
                        )}
                      </div>
                      <div>
                        <p className="font-medium text-gray-900">
                          {game.game_mode === 'custom' ? t('game.mode.custom') : t('game.mode.spaced')} - {game.language.toUpperCase()}
                        </p>
                        <p className={`text-sm ${game.completed ? 'text-gray-500' : 'text-red-500'}`}>
                          {new Date(game.created_at).toLocaleDateString()} {new Date(game.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })}
                        </p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="font-medium text-gray-900">
                        {game.completed ? (
                          `${game.correct_words || 0}/${game.total_words}`
                        ) : (
                          <span className="text-red-600">{t('game.incomplete')}</span>
                        )}
                      </p>
                      <p className="text-sm text-gray-500">
                        {game.completed ? (
                          `${((game.average_response_time || 0) / 1000).toFixed(1)}s ${t('dashboard.avg')}`
                        ) : (
                          t('game.notFinished')
                        )}
                      </p>
                    </div>
                  </div>
                </button>
                
                {/* Word Attempts Panel */}
                {selectedSession === game.session_id && (
                  <div className="bg-gray-50 p-4 rounded-lg mt-2 mb-4">
                    {loadingAttempts ? (
                      <div className="flex justify-center py-4">
                        <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-indigo-600"></div>
                      </div>
                    ) : (
                      <div className="space-y-2">
                        {wordAttempts.map((attempt, index) => (
                          <div
                            key={attempt.word_id}
                            className={`flex items-center justify-between p-2 rounded ${
                              attempt.is_correct ? 'bg-green-50' : 'bg-red-50'
                            }`}
                          >
                            <div className="flex items-center gap-4">
                              <span className="text-gray-500">{index + 1}.</span>
                              <div>
                                <p className="font-medium">{attempt.words.text}</p>
                                <p className={`text-sm ${attempt.is_correct ? 'text-green-600' : 'text-red-600'}`}>
                                  {attempt.user_input || t('dashboard.noAnswer')}
                                </p>
                              </div>
                            </div>
                            <div className="text-sm text-gray-500">
                              {(attempt.response_time_ms / 1000).toFixed(1)}s
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </div>
            ))}
            {stats?.recentGames.length === 0 && (
              <p className="text-center text-gray-500 py-4">{t('dashboard.noGames')}</p>
            )}
          </div>
        </div>

        {/* Achievements */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">{t('dashboard.achievements')}</h2>
          
          {/* Apprenti Linguiste Section */}
          <div className="mb-8 bg-gradient-to-br from-indigo-50 to-purple-50 p-6 rounded-lg">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 bg-indigo-100 rounded-full text-indigo-600">
                <Trophy size={24} />
              </div>
              <div>
                <h3 className="font-semibold text-gray-800">{t('achievements.apprentiLinguiste')}</h3>
                <p className="text-sm text-gray-500">{t('achievements.apprentiLinguisteDesc')}</p>
                <div className="mt-2">
                  {stats?.daily.total_words_correct > 0 && (
                    <div className="relative pt-1">
                      <div className="flex mb-2 items-center justify-between">
                        <div>
                          <span className="text-xs font-semibold inline-block py-1 px-2 uppercase rounded-full text-indigo-600 bg-indigo-200">
                            {stats.daily.total_words_correct} mots maîtrisés
                          </span>
                        </div>
                        <div className="text-right">
                          <span className="text-xs font-semibold inline-block text-indigo-600">
                            {(() => {
                              const tiers = [10, 25, 50, 75, 100, 125, 150, 175, 200, 250, 300, 350, 400, 450, 500];
                              const currentTier = tiers.find(tier => stats.daily.total_words_correct < tier) || tiers[tiers.length - 1];
                              const previousTier = tiers[tiers.indexOf(currentTier) - 1] || 0;
                              const nextTierName = (() => {
                                switch(currentTier) {
                                  case 10: return 'Débutant des Mots';
                                  case 25: return 'Amateur de Lettres';
                                  case 50: return 'Explorateur du Vocabulaire';
                                  case 75: return 'Curieux des Mots';
                                  case 100: return 'Collectionneur de Mots';
                                  case 125: return 'Détective Orthographique';
                                  case 150: return 'Chasseur de Mots';
                                  case 175: return 'Expert en Syllabes';
                                  case 200: return 'Archiviste des Lettres';
                                  case 250: return 'Maître du Lexique';
                                  case 300: return 'Dompteur de Mots Difficiles';
                                  case 350: return 'Savant du Langage';
                                  case 400: return 'Génie des Dictées';
                                  case 450: return 'Scribe Virtuel';
                                  case 500: return 'Professeur d\'Orthographe';
                                  default: return '';
                                }
                              })();
                              return `${previousTier} / ${currentTier} - ${nextTierName}`;
                            })()}
                          </span>
                        </div>
                      </div>
                      <div className="overflow-hidden h-2 mb-4 text-xs flex rounded bg-indigo-200">
                        <div
                          style={{ 
                            width: (() => {
                              const tiers = [10, 25, 50, 75, 100, 125, 150, 175, 200, 250, 300, 350, 400, 450, 500];
                              const currentTier = tiers.find(tier => stats.daily.total_words_correct < tier) || tiers[tiers.length - 1];
                              const previousTier = tiers[tiers.indexOf(currentTier) - 1] || 0;
                              const progress = ((stats.daily.total_words_correct - previousTier) / (currentTier - previousTier)) * 100;
                              return `${Math.min(100, Math.max(0, progress))}%`;
                            })()
                          }}
                          className="shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center bg-gradient-to-r from-indigo-500 to-purple-500"
                        />
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>
            <div className="space-y-4">
              {stats?.achievements
                .filter(a => a.condition_type === 'words_mastered' && a.condition_value <= 100) // Only show first 5 tiers
                .sort((a, b) => a.condition_value - b.condition_value)
                .map((achievement, index, array) => {
                  const mastered = stats.daily.total_words_correct || 0;
                  const currentTier = achievement.condition_value;
                  const nextTier = array[index + 1]?.condition_value || currentTier + 25;
                  const isUnlocked = mastered >= currentTier;
                  const isNextTier = mastered >= currentTier && mastered < nextTier;
                  const progress = isNextTier 
                    ? Math.min(100, ((mastered - currentTier) / (nextTier - currentTier)) * 100)
                    : 0;

                  return (
                    <div 
                      key={achievement.name} 
                      className={`p-3 rounded-lg transition-colors ${
                        isUnlocked 
                          ? isNextTier
                            ? 'bg-white shadow-sm ring-1 ring-indigo-100' 
                            : 'bg-gradient-to-r from-green-50 to-emerald-50'
                          : 'bg-gray-100/50'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-2">
                        <div className="flex items-center gap-2">
                          <div className={`p-1.5 rounded-full ${
                            isUnlocked 
                              ? isNextTier 
                                ? 'bg-gradient-to-br from-indigo-100 to-purple-100 text-indigo-600' 
                                : 'bg-gradient-to-br from-green-100 to-emerald-100 text-green-600'
                              : 'bg-gray-100 text-gray-400'
                          }`}>
                            <Book className="w-4 h-4" />
                          </div>
                          <span className={`font-medium ${isUnlocked ? 'text-gray-900' : 'text-gray-500'}`}>
                            {achievement.name}
                          </span>
                        </div>
                        <span className={`text-sm ${
                          isUnlocked 
                            ? isNextTier 
                              ? 'text-indigo-600 font-medium' 
                              : 'text-green-600'
                            : 'text-gray-500'
                        }`}>
                          {isUnlocked ? (
                            isNextTier ? `${mastered}/${nextTier} mots` : '✓'
                          ) : (
                            `0/${currentTier} mots`
                          )}
                        </span>
                      </div>
                      <div className="h-1.5 bg-gray-100 rounded-full overflow-hidden">
                        {isNextTier ? (
                          <div 
                            className="h-full transition-all duration-500 rounded-full bg-gradient-to-r from-indigo-600 to-purple-600"
                            style={{ 
                              width: `${progress}%`,
                              boxShadow: '0 0 8px rgba(99, 102, 241, 0.4)'
                            }}
                          />
                        ) : (
                          <div 
                            className={`h-full rounded-full ${
                              isUnlocked 
                                ? 'bg-gradient-to-r from-green-500 to-emerald-500' 
                                : 'bg-gray-200'
                            }`}
                            style={{ width: isUnlocked ? '100%' : '0%' }}
                          />
                        )}
                      </div>
                    </div>
                  );
                })}
            </div>
          </div>
          
          {/* Succès Débloqués */}
          <div className="space-y-4">
            <h3 className="font-semibold text-gray-800 mb-2">{t('dashboard.achievementsInProgress')}</h3>
            <div className="space-y-3">
              {stats?.achievements
                .filter(a => a.condition_type !== 'words_mastered' && a.condition_type !== 'words_mastered_parent')
                .filter(a => a.achieved_at)
                .map((achievement) => {
                  const Icon = {
                    award: Award,
                    star: Star,
                    book: Book,
                    timer: Timer,
                    calendar: Calendar
                  }[achievement.icon_name as keyof typeof icons] || Trophy;

                  return (
                    <div key={achievement.name} className="flex items-center gap-4 p-4 bg-gradient-to-br from-green-50 to-emerald-50 rounded-lg transform transition-all hover:scale-[1.02]">
                      <div className="p-2 bg-gradient-to-br from-green-100 to-emerald-100 rounded-full text-green-600">
                        <Icon size={24} />
                      </div>
                      <div>
                        <p className="font-medium text-gray-900">{achievement.name}</p>
                        <p className="text-sm text-gray-500">{achievement.description}</p>
                      </div>
                    </div>
                  );
                })}
            </div>
            
            {/* Succès à Débloquer */}
            <h3 className="font-semibold text-gray-800 mt-6 mb-2">{t('dashboard.achievementsToUnlock')}</h3>
            <div className="space-y-3">
              {/* Apprenti Linguiste Section */}
              <div className="mb-4 bg-gray-50/50 rounded-lg border border-gray-100">
                <div className="flex items-center gap-3 p-4">
                  <div className="p-2 bg-gray-100 rounded-full text-gray-400">
                    <Trophy size={24} />
                  </div>
                  <div>
                    <h3 className="font-medium text-gray-700">{t('achievements.apprentiLinguiste')}</h3>
                    <p className="text-sm text-gray-500">{t('achievements.apprentiLinguisteDesc')}</p>
                    <div className="mt-2">
                      {stats?.daily.total_words_correct > 0 && (
                        <div className="relative pt-1">
                          <div className="flex mb-2 items-center justify-between">
                            <div>
                              <span className="text-xs font-semibold inline-block py-1 px-2 uppercase rounded-full text-gray-600 bg-gray-200">
                                {stats.daily.total_words_correct} mots maîtrisés
                              </span>
                            </div>
                            <div className="text-right">
                              <span className="text-xs font-semibold inline-block text-gray-600">
                                {(() => {
                                  const tiers = [10, 25, 50, 75, 100, 125, 150, 175, 200, 250, 300, 350, 400, 450, 500];
                                  const currentTier = tiers.find(tier => stats.daily.total_words_correct < tier) || tiers[tiers.length - 1];
                                  const previousTier = tiers[tiers.indexOf(currentTier) - 1] || 0;
                                  const nextTierName = (() => {
                                    switch(currentTier) {
                                     case 10: return t('achievements.debutantDesMots');
                                     case 25: return t('achievements.amateurDeLettres');
                                     case 50: return t('achievements.explorateurDuVocabulaire');
                                     case 75: return t('achievements.curieuxDesMots');
                                     case 100: return t('achievements.collectionneurDeMots');
                                     case 125: return t('achievements.detectiveOrthographique');
                                     case 150: return t('achievements.chasseurDeMots');
                                     case 175: return t('achievements.expertEnSyllabes');
                                     case 200: return t('achievements.archivisteDesLettres');
                                     case 250: return t('achievements.maitreDuLexique');
                                     case 300: return t('achievements.dompteurDeMotsDifficiles');
                                     case 350: return t('achievements.savantDuLangage');
                                     case 400: return t('achievements.genieDesDictees');
                                     case 450: return t('achievements.scribeVirtuel');
                                     case 500: return t('achievements.professeurOrthographe');
                                      default: return '';
                                    }
                                  })();
                                  return `${previousTier} / ${currentTier} - ${nextTierName}`;
                                })()}
                              </span>
                            </div>
                          </div>
                          <div className="overflow-hidden h-2 mb-4 text-xs flex rounded bg-gray-200">
                            <div
                              style={{ 
                                width: (() => {
                                  const tiers = [10, 25, 50, 75, 100, 125, 150, 175, 200, 250, 300, 350, 400, 450, 500];
                                  const currentTier = tiers.find(tier => stats.daily.total_words_correct < tier) || tiers[tiers.length - 1];
                                  const previousTier = tiers[tiers.indexOf(currentTier) - 1] || 0;
                                  const progress = ((stats.daily.total_words_correct - previousTier) / (currentTier - previousTier)) * 100;
                                  return `${Math.min(100, Math.max(0, progress))}%`;
                                })()
                              }}
                              className="shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center bg-gray-400"
                            />
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>

              {stats?.achievements
                .filter(a => a.condition_type !== 'words_mastered' && a.condition_type !== 'words_mastered_parent')
                .filter(a => !a.achieved_at) // Only show unachieved ones
                .map((achievement) => {
                  const Icon = {
                    award: Award,
                    star: Star,
                    book: Book,
                    timer: Timer,
                    calendar: Calendar
                  }[achievement.icon_name as keyof typeof icons] || Trophy;

                  return (
                    <div key={achievement.name} className="flex items-center gap-4 p-4 bg-gray-50/50 rounded-lg border border-gray-100">
                      <div className="p-2 bg-gray-100 rounded-full text-gray-400">
                        <Icon size={24} />
                      </div>
                      <div>
                        <p className="font-medium text-gray-700">{achievement.name}</p>
                        <p className="text-sm text-gray-500">{achievement.description}</p>
                      </div>
                    </div>
                  );
                })}
            </div>
            
            
            {stats?.achievements.length === 0 && (
              <p className="text-center text-gray-500 py-4">{t('dashboard.noAchievements')}</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default Dashboard;