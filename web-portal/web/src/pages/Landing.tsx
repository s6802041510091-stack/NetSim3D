import { Link } from 'react-router';
import { GameIcon, LangToggle, SimIcon } from '../components';
import { useI18n } from '../i18n';
import { HomeMark, phrase, Shape, useHomeAction } from './landing-shared';
import './landing.css';

function Star() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className="bs-star">
      <path d="M12 2.5l2.9 6 6.6.8-4.9 4.6 1.3 6.5L12 17.2l-5.9 3.2 1.3-6.5L2.5 9.3l6.6-.8z" fill="currentColor" />
    </svg>
  );
}

/** A few things from the real game, scattered like stickers on a desk:
 *  the level 3 mission card, its Command Prompt, the score stamp. */
function Collage() {
  const { t } = useI18n();
  return (
    <div className="bc" aria-hidden="true">
      <Shape kind="circle" className="bc-blob bc-blob-yellow" />
      <Shape kind="diamond" className="bc-blob bc-blob-blue" />
      <Shape kind="tri" className="bc-blob bc-blob-red" />

      <div className="bc-mission">
        <span className="bc-mission-tag">{t('home.cardMission')}</span>
        <strong>{t('home.cardTitle')}</strong>
        <ol>
          <li className="is-done">{t('home.cardStep1')}</li>
          <li className="is-done">{t('home.cardStep2')}</li>
          <li className="is-now">{t('home.cardStep3')}</li>
        </ol>
      </div>

      <div className="bc-term">
        <div className="bc-term-bar"><i /><i /><i /> Command Prompt</div>
        <pre>
          <span className="bc-term-in">C:\&gt; ping 192.168.1.1</span>{'\n'}
          Reply from 192.168.1.1: time=1ms{'\n'}
          Reply from 192.168.1.1: time=1ms
        </pre>
      </div>

      <div className="bc-score">
        <span className="bc-score-stars"><Star /><Star /><Star /></span>
        <strong>85</strong>
        <span>{t('home.score')}</span>
      </div>

      <span className="bc-levels">{t('home.levels')}</span>

      <svg viewBox="0 0 120 60" className="bc-squiggle">
        <path d="M4 40c14-26 24-26 30 0s18 26 28 0 18-26 28 0 16 18 26 2" fill="none" stroke="currentColor" strokeWidth="5" strokeLinecap="round" />
      </svg>
    </div>
  );
}

/** The home page: light and friendly, with real pieces of the game and the Simulation. */
export default function Landing() {
  const { t } = useI18n();
  const { target, label } = useHomeAction();

  return (
    <div className="bright">
      <header className="bright-bar">
        <Link to="/" className="bright-brand" aria-label="NetSim">
          <HomeMark className="bright-mark" />
          <span>NetSim</span>
        </Link>
        <nav className="bright-bar-right">
          <LangToggle />
          <Link to={target} className="bright-btn bright-btn-sm">{label}</Link>
        </nav>
      </header>

      <main>
        <section className="bright-hero">
          <div className="bright-copy">
            <p className="bright-chip">
              <Shape kind="tri" className="bright-chip-shape bcs-red" />
              <Shape kind="diamond" className="bright-chip-shape bcs-blue" />
              <Shape kind="circle" className="bright-chip-shape bcs-yellow" />
              <Shape kind="square" className="bright-chip-shape bcs-green" />
              {t('app.sub')}
            </p>
            <h1 className="bright-title">
              <span><mark>{phrase(t('home.title1'))}</mark></span>
              <span>{phrase(t('home.title2'))}</span>
            </h1>
            <p className="bright-lead">{t('landing.forWho')}</p>
            <div className="bright-cta">
              <Link to={target} className="bright-btn bright-btn-xl">
                {label}
                <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true">
                  <path d="M5 12h13M13 6l6 6-6 6" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </Link>
              <span className="bright-note" aria-hidden="true">
                <svg viewBox="0 0 80 50" className="bright-note-arrow">
                  <path d="M74 8C60 4 40 8 30 22S14 40 6 38M6 38l9-9M6 38l12 3" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                {t('home.note')}
              </span>
            </div>
          </div>
          <Collage />
        </section>

        <section className="bright-ways">
          <header className="bright-ways-head">
            <h2 className="bright-ways-title">{t('home.waysTitle')}</h2>
            <p>{t('home.realScreens')}</p>
          </header>

          <article className="bshow bshow-sim">
            <div className="bshow-copy">
              <span className="bshow-no">01</span>
              <h3><span className="bright-way-icon bwi-blue"><SimIcon /></span>{t('landing.simTitle')}</h3>
              <p>{t('landing.simText')}</p>
              <ul className="bshow-chips">
                <li><i className="dot-blue" />Router · Switch · PC</li>
                <li><i className="dot-yellow" />{t('home.simChip2')}</li>
                <li><i className="dot-green" />{t('home.simChip3')}</li>
              </ul>
            </div>
            <figure className="bshow-media">
              <Shape kind="diamond" className="bshow-blob bshow-blob-blue" />
              <div className="bshow-frame">
                <div className="bshow-frame-bar"><i /><i /><i /><span>netsim / sim</span></div>
                <img src="/images/home/simulation.webp" width="1600" height="961" loading="lazy" alt={t('home.simAlt')} />
              </div>
              <span className="bshow-note bshow-note-sim" aria-hidden="true">
                {t('home.simNote')}
                <svg viewBox="0 0 70 44"><path d="M4 6c18 2 34 10 42 24M46 30l-10-2M46 30l2-10" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" /></svg>
              </span>
            </figure>
          </article>

          <article className="bshow bshow-game">
            <div className="bshow-copy">
              <span className="bshow-no">02</span>
              <h3><span className="bright-way-icon bwi-red"><GameIcon /></span>{t('landing.gameTitle')}</h3>
              <p>{t('landing.gameText')}</p>
              <ul className="bshow-chips">
                <li><i className="dot-red" />{t('home.levels')}</li>
                <li><i className="dot-blue" />{t('home.gameChip2')}</li>
                <li><i className="dot-purple" />{t('home.gameChip3')}</li>
              </ul>
            </div>
            <figure className="bshow-media">
              <Shape kind="tri" className="bshow-blob bshow-blob-red" />
              <div className="bshow-frame">
                <div className="bshow-frame-bar"><i /><i /><i /><span>netsim / game</span></div>
                <img src="/images/home/game-it-room.webp" width="1600" height="900" loading="lazy" alt={t('home.gameAlt')} />
              </div>
              <img className="bshow-inset" src="/images/home/game-desktop-cmd.webp" width="740" height="440" loading="lazy" alt={t('home.gameAlt2')} />
              <span className="bshow-note bshow-note-game" aria-hidden="true">
                <svg viewBox="0 0 70 44"><path d="M66 8C48 8 30 14 22 30M22 30l10-1M22 30l-1-10" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" /></svg>
                {t('home.gameNote')}
              </span>
            </figure>
          </article>
        </section>
      </main>

      <footer className="bright-foot">
        <p>{t('landing.privacy')}</p>
      </footer>
    </div>
  );
}
