import { useI18n } from '../i18n';
import { nextStep, useSession } from '../session';

/** Where the home page's main button goes, and what it says. */
export function useHomeAction() {
  const { t } = useI18n();
  const { me } = useSession();
  return {
    target: me ? nextStep(me) ?? '/lobby' : '/login',
    label: me ? t('landing.continue') : t('landing.login'),
  };
}

/** Small NetSim mark: three linked nodes in a rounded square. */
export function HomeMark({ className = 'home-mark', ink = '#fff' }: { className?: string; ink?: string }) {
  return (
    <svg viewBox="0 0 32 32" aria-hidden="true" className={className}>
      <rect x="1" y="1" width="30" height="30" rx="9" fill="currentColor" />
      <g stroke={ink} strokeWidth="1.8" fill="none" strokeLinecap="round">
        <path d="M16 11v5M10.5 21.5 16 16l5.5 5.5" />
      </g>
      <g fill={ink}>
        <circle cx="16" cy="9.5" r="2.6" />
        <circle cx="9.5" cy="22.5" r="2.6" />
        <circle cx="22.5" cy="22.5" r="2.6" />
      </g>
    </svg>
  );
}

/** A headline phrase whose "|" marks are the only places it may wrap (Thai has
 *  no spaces, so the browser would otherwise split words like เครือ|ข่าย). */
export function phrase(text: string) {
  const parts = text.split('|');
  if (parts.length === 1) return text;
  return parts.map((part, i) => (
    <span key={part} className="home-nb">{i > 0 && <wbr />}{part}</span>
  ));
}

/** The four playful shapes used around the pages. */
export function Shape({ kind, className }: { kind: 'tri' | 'circle' | 'square' | 'diamond'; className?: string }) {
  return (
    <svg viewBox="0 0 40 40" aria-hidden="true" className={className}>
      {kind === 'tri' && <path d="M20 4 37 34H3z" fill="currentColor" />}
      {kind === 'circle' && <circle cx="20" cy="20" r="16" fill="currentColor" />}
      {kind === 'square' && <rect x="5" y="5" width="30" height="30" rx="4" fill="currentColor" />}
      {kind === 'diamond' && <path d="M20 2 38 20 20 38 2 20z" fill="currentColor" />}
    </svg>
  );
}
