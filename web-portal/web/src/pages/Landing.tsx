import { Link } from 'react-router';
import { GameIcon, LangToggle, Logo, SimIcon } from '../components';
import { useI18n } from '../i18n';
import { nextStep, useSession } from '../session';

export default function Landing() {
  const { t } = useI18n();
  const { me } = useSession();
  const target = me ? nextStep(me) ?? '/lobby' : '/login';

  return (
    <div className="page landing">
      <div className="landing-lang"><LangToggle /></div>
      <section className="landing-panel glass">
        <Logo size="lg" />
        <p className="landing-sub">{t('app.sub')}</p>
        <p className="landing-tagline">{t('app.tagline')}</p>

        <Link to={target} className="btn btn-primary btn-xl">
          <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path d="M8 5l11 7-11 7z" fill="currentColor" /></svg>
          {me ? t('landing.continue') : t('landing.login')}
        </Link>

        <div className="landing-parts">
          <div className="part">
            <span className="part-icon part-sim"><SimIcon /></span>
            <div>
              <strong>{t('landing.simTitle')}</strong>
              <p>{t('landing.simText')}</p>
            </div>
          </div>
          <div className="part">
            <span className="part-icon part-game"><GameIcon /></span>
            <div>
              <strong>{t('landing.gameTitle')}</strong>
              <p>{t('landing.gameText')}</p>
            </div>
          </div>
        </div>

        <p className="landing-for">{t('landing.forWho')}</p>
        <p className="landing-privacy">{t('landing.privacy')}</p>
      </section>
    </div>
  );
}
