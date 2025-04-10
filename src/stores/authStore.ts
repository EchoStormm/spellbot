import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { supabase } from '../lib/supabase';
import type { User } from '@supabase/supabase-js';
import type { AppLanguage } from '../types/user';

/**
 * AuthState interface defines the structure of the authentication store
 * Manages:
 * - User authentication state
 * - User profile data
 * - Language preferences
 * - Education level settings
 * - Session management
 */
interface AuthState {
  isAuthenticated: boolean;
  username: string;
  displayName: string;
  educationLevel: string;
  defaultLanguage: string;
  appLanguage: AppLanguage;
  user: User | null;
  isLoading: boolean;
  login: (username: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  logout: () => void;
  setUser: (user: User | null) => void;
  setLoading: (loading: boolean) => void;
  updateDisplayName: (newName: string) => Promise<void>;
  updateEmail: (newEmail: string) => Promise<void>;
  updateSettings: (settings: {
    educationLevel?: string;
    defaultLanguage?: string;
    appLanguage?: AppLanguage;
  }) => Promise<void>;
  deleteAccount: () => Promise<void>;
}

/**
 * Authentication store using Zustand
 * Handles:
 * - User authentication flows (login, register, logout)
 * - Profile management
 * - Settings persistence
 * - Session state management
 * - Supabase integration
 */
export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      isAuthenticated: false,
      username: '',
      displayName: '',
      educationLevel: 'primary',
      defaultLanguage: 'fr',
      appLanguage: 'fr',
      user: null,
      isLoading: false,
      setLoading: (loading: boolean) => set({ isLoading: loading }),
      login: async (email: string, password: string) => {
        const { data, error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        
        if (error) throw error;
        
        set({ 
          isAuthenticated: true, 
          username: email.split('@')[0],
          displayName: data.user.user_metadata.display_name || email.split('@')[0],
          educationLevel: data.user.user_metadata.education_level || 'primary',
          defaultLanguage: data.user.user_metadata.default_language || 'fr',
          appLanguage: data.user.user_metadata.app_language || 'fr',
          user: data.user 
        });
      },
      register: async (email: string, password: string) => {
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
        });
        
        if (error) throw error;
        
        set({ 
          isAuthenticated: true, 
          username: email.split('@')[0],
          displayName: data.user.user_metadata.display_name || email.split('@')[0],
          educationLevel: data.user.user_metadata.education_level || 'primary',
          defaultLanguage: data.user.user_metadata.default_language || 'fr',
          appLanguage: data.user.user_metadata.app_language || 'fr',
          user: data.user 
        });
      },
      logout: async () => {
        const { error } = await supabase.auth.signOut();
        if (error) throw error;
        const currentAppLanguage = useAuthStore.getState().appLanguage;
        set(state => ({ 
          isAuthenticated: false, 
          username: '', 
          displayName: '', 
          educationLevel: 'primary',
          defaultLanguage: 'fr',
          user: null,
          appLanguage: currentAppLanguage // Preserve language preference
        }));
      },
      setUser: (user) => set({ 
        user,
        isAuthenticated: !!user,
        username: user?.email?.split('@')[0] || '',
        displayName: user?.user_metadata.display_name || user?.email?.split('@')[0] || '',
        educationLevel: user?.user_metadata.education_level || 'primary',
        defaultLanguage: user?.user_metadata.default_language || 'fr',
        // Keep existing app language if set, otherwise use metadata or default to 'fr'
        appLanguage: useAuthStore.getState().appLanguage || user?.user_metadata.app_language || 'fr'
      }),
      updateDisplayName: async (newName: string) => {
        const { data, error } = await supabase.auth.updateUser({
          data: { display_name: newName }
        });

        if (error) throw error;

        set(state => ({
          ...state,
          displayName: newName,
          user: data.user
        }));
      },
      updateEmail: async (newEmail: string) => {
        const { data, error } = await supabase.auth.updateUser({
          email: newEmail
        });

        if (error) throw error;

        set(state => ({
          ...state,
          username: newEmail.split('@')[0],
          user: data.user
        }));
      },
      updateSettings: async (settings) => {
        const { data, error } = await supabase.auth.updateUser({
          data: {
            education_level: settings.educationLevel,
            default_language: settings.defaultLanguage,
            app_language: settings.appLanguage
          }
        });

        if (error) throw error;

        set(state => ({
          ...state,
          educationLevel: settings.educationLevel || state.educationLevel,
          defaultLanguage: settings.defaultLanguage || state.defaultLanguage,
          appLanguage: settings.appLanguage || state.appLanguage,
          user: data.user
        }));
      },
      deleteAccount: async () => {
        const { error } = await supabase.auth.admin.deleteUser(
          useAuthStore.getState().user?.id || ''
        );
        
        if (error) throw error;
        
        await useAuthStore.getState().logout();
      }
    }),
    {
      name: 'auth-storage',
    }
  )
);