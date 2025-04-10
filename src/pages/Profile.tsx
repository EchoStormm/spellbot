import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../stores/authStore';
import { useTranslation } from '../hooks/useTranslation';
import { Loader2, Check, X, Mail, User, GraduationCap, Languages, Clock, AlertTriangle, Trophy } from 'lucide-react';
import { EDUCATION_LEVELS, APP_LANGUAGES } from '../types/user';
import { SUPPORTED_LANGUAGES } from '../types/game';
import { supabase } from '../lib/supabase';

interface UserStats {
  gamesPlayed: number;
  gamesIncomplete: number;
  winRate: number;
  averageScore: number;
}

function Profile() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const { 
    displayName, 
    educationLevel,
    defaultLanguage,
    appLanguage,
    updateDisplayName, 
    updateEmail,
    updateSettings,
    deleteAccount,
    logout 
  } = useAuthStore();
  const [newDisplayName, setNewDisplayName] = useState(displayName);
  const [newEmail, setNewEmail] = useState('');
  const [newEducationLevel, setNewEducationLevel] = useState(educationLevel);
  const [newDefaultLanguage, setNewDefaultLanguage] = useState(defaultLanguage);
  const [newAppLanguage, setNewAppLanguage] = useState(appLanguage);
  const [isEditingProfile, setIsEditingProfile] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [stats, setStats] = useState<UserStats>({
    gamesPlayed: 0,
    gamesIncomplete: 0,
    winRate: 0,
    averageScore: 0
  });
  const user = useAuthStore(state => state.user);

  useEffect(() => {
    if (user?.email) {
      setNewEmail(user.email);
    }
  }, [user?.email]);

  useEffect(() => {
    const fetchStats = async () => {
      if (!user?.id) return;

      try {
        // Fetch game sessions for statistics
        const { data: sessions } = await supabase
          .from('game_sessions').select('*')
          .eq('user_id', user.id);

        if (sessions) {
          const completedGames = sessions.filter(s => s.completed);
          const incompleteGames = sessions.filter(s => !s.completed);
          const totalAccuracy = completedGames.reduce((acc, s) => acc + (s.correct_words / s.total_words), 0);

          setStats({
            gamesPlayed: completedGames.length,
            gamesIncomplete: incompleteGames.length,
            averageScore: completedGames.length > 0 ? (totalAccuracy / completedGames.length) * 100 : 0
          });
        }
      } catch (err) {
        console.error('Error fetching stats:', err);
      }
    };

    fetchStats();

    // Set up real-time subscription for game sessions
    const subscription = supabase
      .channel('game_sessions_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'game_sessions',
          filter: `user_id=eq.${user?.id}`
        },
        () => {
          fetchStats();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [user?.id]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    setIsLoading(true);
    setError('');

    try {
      // Update all fields at once
      const trimmedDisplayName = newDisplayName.trim();
      const trimmedEmail = newEmail.trim();

      // Update display name if changed
      if (trimmedDisplayName !== displayName) {
        await updateDisplayName(trimmedDisplayName);
      }

      // Update email if changed
      if (trimmedEmail !== user?.email) {
        await updateEmail(trimmedEmail);
      }

      // Update settings if any changed
      if (newEducationLevel !== educationLevel ||
          newDefaultLanguage !== defaultLanguage ||
          newAppLanguage !== appLanguage) {
        await updateSettings({
          educationLevel: newEducationLevel,
          defaultLanguage: newDefaultLanguage,
          appLanguage: newAppLanguage
        });
      }
      
      setIsEditingProfile(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update profile');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto">
      <div className="bg-white rounded-lg shadow-md p-8">
        <div className="flex items-center gap-6 mb-8">
          <div className="w-32 h-32 rounded-full bg-indigo-100 flex items-center justify-center">
            <span className="text-4xl font-bold text-indigo-600">
              {displayName.charAt(0).toUpperCase()}
            </span>
          </div>
          <div className="flex-1">
            <h1 className="text-3xl font-bold text-gray-900">{displayName}</h1>
            <div className="mt-2 space-y-1">
              <p className="text-gray-600 flex items-center gap-2">
                <GraduationCap className="w-4 h-4" />
                {t(`education.${educationLevel}`)}
              </p>
              <p className="text-gray-600 flex items-center gap-2">
                <Languages className="w-4 h-4" />
                {t('profile.defaultLanguage')}: {SUPPORTED_LANGUAGES.find(lang => lang.code === defaultLanguage)?.name}
              </p>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="bg-gray-50 rounded-lg p-6">
            <h2 className="text-xl font-semibold text-gray-900 mb-4">{t('profile.recentActivity')}</h2>
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <span className="text-gray-600">{t('profile.gamesPlayed')}</span>
                <span className="font-semibold">{stats.gamesPlayed}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-600">{t('profile.gamesIncomplete')}</span>
                <span className="font-semibold">{stats.gamesIncomplete}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-600">{t('profile.averageScore')}</span>
                <span className="font-semibold">{stats.averageScore.toFixed(1)}%</span>
              </div>
            </div>
          </div>

          <div className="bg-gray-50 rounded-lg p-6">
            <h2 className="text-xl font-semibold text-gray-900 mb-4">{t('profile.settings')}</h2>
            <div className="space-y-4">
              <button 
                onClick={() => {
                  navigate('/reset-password');
                }}
                className="w-full py-2 px-4 bg-indigo-600 text-white rounded hover:bg-indigo-700 transition-colors"
              >
                {t('profile.changePassword')}
              </button>
              <button 
                onClick={() => setIsEditingProfile(true)}
                className="w-full py-2 px-4 bg-white border border-gray-300 text-gray-700 rounded hover:bg-gray-50 transition-colors"
              >
                {t('profile.editProfile')}
              </button>
              <button
                onClick={() => setShowDeleteConfirm(true)}
                className="w-full py-2 px-4 bg-white border border-red-300 text-red-600 rounded hover:bg-red-50 transition-colors"
              >
                {t('profile.deleteAccount')}
              </button>
              <button
                onClick={logout}
                className="w-full py-2 px-4 bg-white border border-gray-300 text-gray-700 rounded hover:bg-gray-50 transition-colors"
              >
                {t('nav.logout')}
              </button>
            </div>
          </div>
        </div>
        
        {/* Edit Profile Modal */}
        {isEditingProfile && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
            <form onSubmit={handleSubmit} className="bg-white rounded-lg shadow-xl p-6 w-full max-w-md">
              <h2 className="text-2xl font-bold text-gray-900 mb-6">{t('profile.editProfile')}</h2>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">{t('profile.email')}</label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                    <input
                      type="email"
                      value={newEmail}
                      onChange={(e) => setNewEmail(e.target.value)}
                      className="w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      placeholder="Enter email address"
                    />
                  </div>
                  <p className="mt-1 text-sm text-gray-500">
                    {t('profile.emailVerification')}
                  </p>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">{t('profile.username')}</label>
                  <div className="flex items-center gap-2">
                    <div className="relative flex-1">
                      <User className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                      <input
                        type="text"
                        value={newDisplayName}
                        onChange={(e) => setNewDisplayName(e.target.value)}
                        className="w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                        placeholder="Enter display name"
                      />
                    </div>
                  </div>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">{t('profile.educationLevel')}</label>
                  <select
                    value={newEducationLevel}
                    onChange={(e) => setNewEducationLevel(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  >
                    {EDUCATION_LEVELS.map(level => (
                      <option key={level.value} value={level.value}>
                        {t(`education.${level.value}`)}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">{t('profile.defaultLanguage')}</label>
                  <select
                    value={newDefaultLanguage}
                    onChange={(e) => {
                      setNewDefaultLanguage(e.target.value);
                    }}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  >
                    {SUPPORTED_LANGUAGES.map((lang) => (
                      <option key={lang.code} value={lang.code} className="font-medium">
                        {t(`language.${lang.code}`)}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">{t('profile.appLanguage')}</label>
                  <select
                    value={newAppLanguage}
                    onChange={(e) => {
                      setNewAppLanguage(e.target.value as AppLanguage);
                    }}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  >
                    {APP_LANGUAGES.map(lang => (
                      <option key={lang.value} value={lang.value} className="font-medium">
                        {lang.label.split(' / ')[0]}
                      </option>
                    ))}
                  </select>
                </div>

                {error && (
                  <p className="text-sm text-red-600">{error}</p>
                )}
              </div>
              
              <div className="mt-6 flex gap-3">
                <button
                  type="submit"
                  disabled={isLoading}
                  className="flex-1 flex items-center justify-center gap-2 py-2 px-4 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50"
                >
                  {isLoading ? (
                    <Loader2 className="animate-spin h-4 w-4" />
                  ) : (
                    <Check className="h-4 w-4" />
                  )}
                  {t('profile.save')}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setIsEditingProfile(false);
                    setNewDisplayName(displayName);
                    setNewEmail(user?.email || '');
                    setError('');
                  }}
                  className="flex-1 py-2 px-4 bg-white border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
                >
                  {t('profile.cancel')}
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Delete Account Confirmation Modal */}
        {showDeleteConfirm && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-lg shadow-xl p-6 w-full max-w-md">
              <div className="flex items-center gap-3 text-red-600 mb-4">
                <AlertTriangle className="w-6 h-6" />
                <h2 className="text-xl font-bold">{t('profile.deleteConfirmTitle')}</h2>
              </div>
              
              <p className="text-gray-600 mb-6">
                {t('profile.deleteConfirmMessage')}
              </p>
              
              <div className="flex gap-3">
                <button
                  onClick={async () => {
                    try {
                      await deleteAccount();
                      navigate('/login');
                    } catch (err) {
                      setError(err instanceof Error ? err.message : 'Failed to delete account');
                    }
                  }}
                  className="flex-1 py-2 px-4 bg-red-600 text-white rounded-md hover:bg-red-700"
                >
                  {t('profile.deleteConfirmYes')}
                </button>
                <button
                  onClick={() => setShowDeleteConfirm(false)}
                  className="flex-1 py-2 px-4 bg-white border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
                >
                  {t('profile.deleteConfirmNo')}
                </button>
              </div>
              
              {error && (
                <p className="mt-3 text-sm text-red-600">{error}</p>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default Profile;