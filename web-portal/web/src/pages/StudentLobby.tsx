import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { api, type StudentClass } from '../api';
import { GameIcon, Notice, Shell, SimIcon, useAction } from '../components';
import { formatDate, useI18n } from '../i18n';
import { useSession } from '../session';

export default function StudentLobby() {
  const { t, lang, errorText } = useI18n();
  const { me, setMe } = useSession();
  const [classes, setClasses] = useState<StudentClass[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [password, setPassword] = useState('');
  const join = useAction();
  const switcher = useAction();

  const load = useCallback(async () => {
    try {
      setClasses((await api.studentClasses()).classes);
      setLoadError(null);
    } catch (err) {
      setLoadError(errorText(err));
    }
  }, [errorText]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!me) return null;
  const active = me.activeClass;

  return (
    <Shell wide>
      <section className="glass panel hello">
        <div>
          <h1>{t('lobby.hello', { name: me.firstName ?? me.displayName })}</h1>
          <p className="muted">
            {t('lobby.activeClass')}:{' '}
            {active ? <strong className="active-class">{active.name} <span className="mono">({active.code})</span></strong> : t('lobby.noClass')}
          </p>
        </div>
      </section>

      <div className="launch-grid">
        <LaunchCard href="/sim/" icon={<SimIcon />} tone="sim" title={t('lobby.simTitle')} text={t('lobby.simText')} disabled={!active} />
        <LaunchCard href="/game/" icon={<GameIcon />} tone="game" title={t('lobby.gameTitle')} text={t('lobby.gameText')} disabled={!active} />
      </div>
      {!active && <p className="glass pill-note">{t('lobby.needClass')}</p>}

      <div className="split">
        <section className="glass panel">
          <h2>{t('lobby.joinTitle')}</h2>
          <p className="muted">{t('lobby.joinIntro')}</p>
          <form
            className="stack"
            onSubmit={(e) => join.run(e, async () => {
              const res = await api.joinClass(code.trim(), password);
              setPassword('');
              setCode('');
              setMe((await api.me()).me);
              await load();
              return t(res.alreadyMember ? 'lobby.already' : 'lobby.joined', { name: res.class.name });
            })}
          >
            <label className="field">
              <span>{t('lobby.code')}</span>
              <input
                required
                className="mono upper"
                maxLength={20}
                autoComplete="off"
                autoCapitalize="characters"
                value={code}
                onChange={(e) => setCode(e.target.value.toUpperCase())}
              />
            </label>
            <label className="field">
              <span>{t('lobby.password')}</span>
              <input required type="password" maxLength={64} autoComplete="off" value={password} onChange={(e) => setPassword(e.target.value)} />
            </label>
            <button type="submit" className="btn btn-primary" disabled={join.busy}>{t('lobby.join')}</button>
            {join.error && <Notice kind="error">{join.error}</Notice>}
            {join.done && <Notice kind="ok">{join.done}</Notice>}
          </form>
        </section>

        <section className="glass panel">
          <h2>{t('lobby.myClasses')}</h2>
          {loadError && <Notice kind="error">{loadError}</Notice>}
          {classes === null && !loadError && <p className="muted">{t('common.loading')}</p>}
          {classes?.length === 0 && <p className="muted">{t('lobby.noClasses')}</p>}
          <ul className="class-list">
            {classes?.map((c) => (
              <li key={c.id} className={active?.id === c.id ? 'class-item current' : 'class-item'}>
                <div>
                  <strong>{c.name}</strong>
                  <span className="mono code-chip">{c.code}</span>
                  <p className="muted small">
                    {t('lobby.teacherBy', { name: c.teacherName })} · {t('lobby.joinedAt', { date: formatDate(c.joinedAt, lang) })}
                  </p>
                </div>
                {active?.id === c.id ? (
                  <span className="badge badge-green">{t('lobby.inUse')}</span>
                ) : (
                  <button
                    type="button"
                    className="btn btn-cream btn-sm"
                    disabled={switcher.busy}
                    onClick={() => switcher.run(null, async () => setMe((await api.setActiveClass(c.id)).me))}
                  >
                    {t('lobby.use')}
                  </button>
                )}
              </li>
            ))}
          </ul>
          {switcher.error && <Notice kind="error">{switcher.error}</Notice>}
        </section>
      </div>
    </Shell>
  );
}

function LaunchCard(props: { href: string; icon: ReactNode; tone: 'sim' | 'game'; title: string; text: string; disabled: boolean }) {
  const { t } = useI18n();
  const body = (
    <>
      <span className={`launch-icon launch-${props.tone}`}>{props.icon}</span>
      <span className="launch-text">
        <strong>{props.title}</strong>
        <span>{props.text}</span>
      </span>
      <span className="btn btn-primary btn-sm launch-go">{t('lobby.open')} →</span>
    </>
  );
  if (props.disabled) {
    return <div className="launch-card glass disabled" aria-disabled="true">{body}</div>;
  }
  return <a className="launch-card glass" href={props.href}>{body}</a>;
}
