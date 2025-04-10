import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Menu, ChevronLeft, Home, PlayCircle, User, Settings, Bell, LogOut, Bug } from 'lucide-react';
import { useTranslation } from './hooks/useTranslation';
import Login from './pages/Login';
import Register from './pages/Register';
import ForgotPassword from './pages/ForgotPassword';
import ResetPassword from './pages/ResetPassword';
import Dashboard from './pages/Dashboard';
import Profile from './pages/Profile';
import NewGame from './pages/NewGame';
import GamePlay from './pages/GamePlay';
import { useAuthStore } from './stores/authStore';
import { supabase } from './lib/supabase';
import { useSidebarStore } from './stores/sidebarStore';

function Sidebar() {
  const { t } = useTranslation();
  const { isOpen, toggle } = useSidebarStore();

  return (
    <div className={`fixed left-0 top-0 h-full bg-indigo-800 text-white transition-all duration-300 ${isOpen ? 'w-64' : 'w-16'}`}>
      <button onClick={toggle} className="p-4 w-full flex justify-end">
        {isOpen ? <ChevronLeft size={24} /> : <Menu size={24} />}
      </button>
      <nav className="flex flex-col gap-2 p-4">
        <a href="/dashboard" className="flex items-center gap-3 p-2 hover:bg-indigo-700 rounded">
          <Home size={24} />
          {isOpen && <span>{t('nav.home')}</span>}
        </a>
        <a href="/new-game" className="flex items-center gap-3 p-2 hover:bg-indigo-700 rounded">
          <PlayCircle size={24} />
          {isOpen && <span>{t('nav.newGame')}</span>}
        </a>
        <a href="/profile" className="flex items-center gap-3 p-2 hover:bg-indigo-700 rounded">
          <User size={24} />
          {isOpen && <span>{t('nav.profile')}</span>}
        </a>
      </nav>
    </div>
  );
}

function Header({ username }: { username: string }) {
  const { logout, displayName } = useAuthStore();
  const { t } = useTranslation();
  
  return (
    <header className="sticky top-0 bg-white shadow-md p-4 flex justify-between items-center z-50">
      <a href="/profile" className="text-lg font-semibold text-indigo-600">{displayName}</a>
      <div className="flex items-center gap-4">
        <button onClick={logout} className="flex items-center gap-2 text-red-600 hover:bg-red-50 p-2 rounded">
          <LogOut size={20} />
          <span>{t('nav.logout')}</span>
        </button>
      </div>
    </header>
  );
}

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const isAuthenticated = useAuthStore(state => state.isAuthenticated);
  const isLoading = useAuthStore(state => state.isLoading);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  return isAuthenticated ? <>{children}</> : <Navigate to="/login" />;
}

function Layout({ children }: { children: React.ReactNode }) {
  const { displayName } = useAuthStore();
  const { isOpen } = useSidebarStore();

  return (
    <div className="min-h-screen bg-gray-50">
      <Sidebar />
      <div className={`transition-all duration-300 ${isOpen ? 'ml-64' : 'ml-16'}`}>
        <Header username={displayName} />
        <main className="p-6">
          {children}
        </main>
      </div>
    </div>
  );
}

function App() {
  const { setUser, setLoading } = useAuthStore();
  const [initialized, setInitialized] = useState(false);

  useEffect(() => {
    // Check initial session
    const initializeAuth = async () => {
      try {
        setLoading(true);
        const { data: { session } } = await supabase.auth.getSession();
        setUser(session?.user ?? null);
      } catch (error) {
        console.error('Error checking auth session:', error);
        setUser(null);
      } finally {
        setLoading(false);
        setInitialized(true);
      }
    };

    initializeAuth();

    // Set up auth state listener
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        setUser(session?.user ?? null);
      }
    );

    return () => {
      subscription.unsubscribe();
    };
  }, [setUser, setLoading]);

  if (!initialized) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  return (
    <Router>
      <Routes>
        <Route path="/register" element={<Register />} />
        <Route path="/login" element={<Login />} />
        <Route path="/forgot-password" element={<ForgotPassword />} />
        <Route path="/reset-password" element={
          <PrivateRoute>
            <ResetPassword />
          </PrivateRoute>
        } />
        <Route path="/dashboard" element={
          <PrivateRoute>
            <Layout>
              <Dashboard />
            </Layout>
          </PrivateRoute>
        } />
        <Route path="/profile" element={
          <PrivateRoute>
            <Layout>
              <Profile />
            </Layout>
          </PrivateRoute>
        } />
        <Route path="/new-game" element={
          <PrivateRoute>
            <Layout>
              <NewGame />
            </Layout>
          </PrivateRoute>
        } />
        <Route path="/game-play" element={
          <PrivateRoute>
            <Layout>
              <GamePlay />
            </Layout>
          </PrivateRoute>
        } />
        <Route path="/" element={<Navigate to="/login" />} />
      </Routes>
    </Router>
  );
}

export default App;