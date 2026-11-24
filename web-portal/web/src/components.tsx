import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { Link, useNavigate } from 'react-router';
import { api } from './api';
import { useI18n } from './i18n';
import { useSession } from './session';

/** NetSim logo: a laptop showing a small network, like the game's. */
export function Logo({ size = 'md' }: { size?: 'md' | 'lg' }) {
  return (
    <span className={`logo logo-${size}`}>
      <svg viewBox="0 0 64 56" aria-hidden="true" className="logo-mark">
        <rect x="6" y="4" width="52" height="36" rx="5" fill="#14234f" />
        <rect x="10" y="8" width="44" height="28" rx="2" fill="#1f7aec" />
        <g fill="#fff" stroke="#fff" strokeWidth="2.5">
          <circle cx="32" cy="15" r="3.2" />
          <circle cx="22" cy="29" r="3.2" />
          <circle cx="42" cy="29" r="3.2" />
          <path d="M32 18v5M22 26v-3h20v3" fill="none" />
        </g>
        <path d="M2 44h60l-4 6H6z" fill="#14234f" />
      </svg>
      <span className="logo-word">
        Net<span className="logo-accent">Sim</span>
      </span>
    </span>
  );
}

/** Network-diagram icon for the Simulation. */
export function SimIcon() {
  return (
    <svg viewBox="0 0 48 48" aria-hidden="true">
      <rect x="18" y="4" width="12" height="9" rx="2" fill="currentColor" />
      <rect x="4" y="34" width="12" height="9" rx="2" fill="currentColor" />
      <rect x="18" y="34" width="12" height="9" rx="2" fill="currentColor" />
      <rect x="32" y="34" width="12" height="9" rx="2" fill="currentColor" />
      <path d="M24 13v21M10 34v-8h28v8" fill="none" stroke="currentColor" strokeWidth="3" />
    </svg>
  );
}

/** Game-controller icon for NetSim3D. */
export function GameIcon() {
  return (
    <svg viewBox="0 0 48 48" aria-hidden="true">
      <path d="M14 12h20c6 0 10 6 11 15 1 7-2 11-6 11-3 0-5-3-7-6H16c-2 3-4 6-7 6-4 0-7-4-6-11 1-9 5-15 11-15z" fill="currentColor" />
      <path d="M14 20v8M10 24h8" stroke="#fff" strokeWidth="3" strokeLinecap="round" />
      <circle cx="33" cy="21" r="2.4" fill="#fff" />
      <circle cx="37" cy="27" r="2.4" fill="#fff" />
    </svg>
  );
}

export function LangToggle() {
  const { lang, setLang, t } = useI18n();
  return (
    <button type="button" className="btn btn-ghost btn-sm" aria-label={t('lang.label')} onClick={() => setLang(lang === 'th' ? 'en' : 'th')}>
      <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
        <circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" strokeWidth="1.8" />
        <path d="M3 12h18M12 3c2.6 2.6 3.8 5.6 3.8 9s-1.2 6.4-3.8 9c-2.6-2.6-3.8-5.6-3.8-9S9.4 5.6 12 3z" fill="none" stroke="currentColor" strokeWidth="1.8" />
      </svg>
      {t('lang.switch')}
    </button>
  );
}

/** Page frame for logged-in pages: top bar with logo, user, language and log out. */
export function Shell({ children, wide = false }: { children: ReactNode; wide?: boolean }) {
  const { me, setMe } = useSession();
  const { t } = useI18n();
  const navigate = useNavigate();

  async function logout() {
    await api.logout().catch(() => {});
    setMe(null);
    navigate('/', { replace: true });
  }

  const name = me?.role === 'student' && me.firstName ? `${me.firstName} ${me.lastName ?? ''}`.trim() : me?.displayName;

  return (
    <div className="page veil">
      <header className="topbar glass">
        <Link to={me && !me.needsRole && !me.needsProfile ? '/lobby' : '/'} className="topbar-home"><Logo /></Link>
        <div className="topbar-right">
          {me && (
            <span className="who">
              <span className="who-name">{name}</span>
              {me.role && <span className={`badge badge-${me.role}`}>{t(`role.${me.role}`)}</span>}
            </span>
          )}
          {me?.role === 'student' && !me.needsProfile && (
            <Link className="btn btn-ghost btn-sm" to="/welcome/profile">{t('nav.profile')}</Link>
          )}
          <LangToggle />
          {me && <button type="button" className="btn btn-ghost btn-sm" onClick={logout}>{t('nav.logout')}</button>}
        </div>
      </header>
      <main className={wide ? 'content content-wide' : 'content'}>{children}</main>
    </div>
  );
}

/** Shows a success or error line under a form. */
export function Notice({ kind, children }: { kind: 'ok' | 'error'; children: ReactNode }) {
  return <p className={`notice notice-${kind}`} role={kind === 'error' ? 'alert' : 'status'}>{children}</p>;
}

/** Runs a form action, tracks busy state and turns failures into a message. */
export function useAction() {
  const { errorText } = useI18n();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  async function run(e: FormEvent | null, action: () => Promise<string | null | void>) {
    e?.preventDefault();
    setBusy(true);
    setError(null);
    setDone(null);
    try {
      const msg = await action();
      if (msg) setDone(msg);
    } catch (err) {
      setError(errorText(err));
    } finally {
      setBusy(false);
    }
  }

  return { busy, error, done, run, setDone };
}

/** A modal confirm box (native <dialog>, so Esc and focus work). */
export function ConfirmDialog(props: {
  open: boolean;
  title: string;
  text: string;
  confirmLabel: string;
  danger?: boolean;
  busy?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const { t } = useI18n();

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (props.open && !d.open) d.showModal();
    if (!props.open && d.open) d.close();
  }, [props.open]);

  return (
    <dialog ref={ref} className="dialog glass" onCancel={(e) => { e.preventDefault(); props.onCancel(); }}>
      <h2>{props.title}</h2>
      <p>{props.text}</p>
      <div className="row-end">
        <button type="button" className="btn btn-cream" onClick={props.onCancel}>{t('common.cancel')}</button>
        <button type="button" className={props.danger ? 'btn btn-danger' : 'btn btn-primary'} disabled={props.busy} onClick={props.onConfirm}>
          {props.confirmLabel}
        </button>
      </div>
    </dialog>
  );
}
