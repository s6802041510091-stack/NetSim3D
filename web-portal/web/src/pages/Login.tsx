import { useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router';
import { api } from '../api';
import { LangToggle, Notice, useAction } from '../components';
import { useI18n } from '../i18n';
import { Loading, nextStep, useSession } from '../session';
import { HomeMark, Shape } from './landing-shared';
import './landing.css';
import './login.css';

export default function Login() {
  const { t } = useI18n();
  const { me, config, loading, setMe } = useSession();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const { busy, error, run } = useAction();

  if (loading) return <Loading />;
  if (me) return <Navigate to={nextStep(me) ?? '/lobby'} replace />;

  return (
    <div className="bright auth">
      <header className="bright-bar">
        <Link to="/" className="bright-brand" aria-label="NetSim">
          <HomeMark className="bright-mark" />
          <span>NetSim</span>
        </Link>
        <nav className="bright-bar-right">
          <LangToggle />
        </nav>
      </header>

      <main className="auth-main">
        <div className="auth-stage">
          <Link to="/" className="auth-back">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M19 12H6M11 6l-6 6 6 6" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            {t('nav.home')}
          </Link>
          <Shape kind="circle" className="auth-shape auth-shape-yellow" />
          <Shape kind="diamond" className="auth-shape auth-shape-blue" />
          <Shape kind="tri" className="auth-shape auth-shape-red" />
          <Shape kind="square" className="auth-shape auth-shape-green" />

          <section className="auth-card">
            <p className="bright-chip auth-chip">
              <Shape kind="tri" className="bright-chip-shape bcs-red" />
              <Shape kind="diamond" className="bright-chip-shape bcs-blue" />
              <Shape kind="circle" className="bright-chip-shape bcs-yellow" />
              <Shape kind="square" className="bright-chip-shape bcs-green" />
              {t('app.sub')}
            </p>
            <h1 className="auth-title">{t('login.title')}</h1>
            <p className="auth-lead">{t('landing.forWho')}</p>

            <button type="button" className="auth-google" disabled={!config?.googleLogin}>
              <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true">
                <path fill="#4285F4" d="M22.6 12.2c0-.8-.1-1.5-.2-2.2H12v4.2h5.9a5 5 0 0 1-2.2 3.3v2.7h3.6c2.1-1.9 3.3-4.8 3.3-8z" />
                <path fill="#34A853" d="M12 23c3 0 5.5-1 7.3-2.7l-3.6-2.8c-1 .7-2.2 1.1-3.7 1.1-2.9 0-5.3-1.9-6.2-4.5H2.1v2.9A11 11 0 0 0 12 23z" />
                <path fill="#FBBC05" d="M5.8 14.1a6.6 6.6 0 0 1 0-4.2V7H2.1a11 11 0 0 0 0 10z" />
                <path fill="#EA4335" d="M12 5.4c1.6 0 3.1.6 4.2 1.7l3.2-3.2A11 11 0 0 0 2.1 7l3.7 2.9C6.7 7.3 9.1 5.4 12 5.4z" />
              </svg>
              {t('login.google')}
            </button>
            {!config?.googleLogin && <p className="auth-hint">{t('login.googleSoon')}</p>}

            {config?.devLogin ? (
              <>
                <div className="auth-divider"><span>{t('login.or')}</span></div>
                <form
                  className="auth-form"
                  onSubmit={(e) => run(e, async () => {
                    const res = await api.devLogin(email.trim(), name.trim());
                    setMe(res.me);
                    navigate(nextStep(res.me) ?? '/lobby', { replace: true });
                  })}
                >
                  <div className="auth-sticky">
                    <strong>{t('login.devBadge')}</strong>
                    <span>{t('login.devNote')}</span>
                  </div>
                  <label className="auth-field">
                    <span>{t('login.email')}</span>
                    <input type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />
                  </label>
                  <label className="auth-field">
                    <span>{t('login.name')}</span>
                    <input type="text" maxLength={100} autoComplete="name" value={name} onChange={(e) => setName(e.target.value)} />
                  </label>
                  <button type="submit" className="bright-btn auth-submit" disabled={busy}>{t('login.submit')}</button>
                  {error && <Notice kind="error">{error}</Notice>}
                </form>
              </>
            ) : (
              !config?.googleLogin && <Notice kind="error">{t('login.unavailable')}</Notice>
            )}
          </section>

        </div>
      </main>

      <footer className="bright-foot">
        <p>{t('landing.privacy')}</p>
      </footer>
    </div>
  );
}
