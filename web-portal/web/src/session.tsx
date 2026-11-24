import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router';
import { api, type Config, type Me } from './api';
import { useI18n } from './i18n';

type Session = {
  me: Me | null;
  config: Config | null;
  loading: boolean;
  error: unknown;
  setMe: (me: Me | null) => void;
  refresh: () => Promise<void>;
};

const SessionContext = createContext<Session | null>(null);

export function SessionProvider({ children }: { children: ReactNode }) {
  const [me, setMe] = useState<Me | null>(null);
  const [config, setConfig] = useState<Config | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<unknown>(null);

  const refresh = useCallback(async () => {
    try {
      const [c, m] = await Promise.all([api.config(), api.me()]);
      setConfig(c);
      setMe(m.me);
      setError(null);
    } catch (err) {
      setError(err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const value = useMemo(() => ({ me, config, loading, error, setMe, refresh }), [me, config, loading, error, refresh]);
  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession(): Session {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error('useSession outside SessionProvider');
  return ctx;
}

/** Where a logged-in user still has to go before the classroom (role, then student details). */
export function nextStep(me: Me): string | null {
  if (me.needsRole) return '/welcome/role';
  if (me.needsProfile) return '/welcome/profile';
  return null;
}

export function Loading() {
  const { t } = useI18n();
  return <div className="loading" role="status">{t('common.loading')}</div>;
}

/**
 * Lets the page through only when the user is logged in and has finished the steps it needs.
 * `step`: 'role' needs only a login, 'profile' needs a role, 'ready' needs everything.
 */
export function Guard({ step = 'ready', children }: { step?: 'role' | 'profile' | 'ready'; children: ReactNode }) {
  const { me, loading } = useSession();
  const location = useLocation();
  if (loading) return <Loading />;
  if (!me) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  if (step !== 'role' && me.needsRole) return <Navigate to="/welcome/role" replace />;
  if (step === 'ready' && me.needsProfile) return <Navigate to="/welcome/profile" replace />;
  return <>{children}</>;
}
