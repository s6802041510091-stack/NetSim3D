import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router';
import { api, type TeacherClass } from '../api';
import { GameIcon, Notice, Shell, SimIcon, useAction } from '../components';
import { useI18n } from '../i18n';
import { useSession } from '../session';

export default function TeacherLobby() {
  const { t, errorText } = useI18n();
  const { me } = useSession();
  const [classes, setClasses] = useState<TeacherClass[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [createdCode, setCreatedCode] = useState<string | null>(null);
  const create = useAction();
  const restore = useAction();

  const load = useCallback(async () => {
    try {
      setClasses((await api.teacherClasses()).classes);
      setLoadError(null);
    } catch (err) {
      setLoadError(errorText(err));
    }
  }, [errorText]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!me) return null;
  const live = classes?.filter((c) => !c.deletedAt) ?? [];
  const deleted = classes?.filter((c) => c.deletedAt) ?? [];

  return (
    <Shell wide>
      <section className="glass panel hello">
        <h1>{t('lobby.hello', { name: me.displayName })}</h1>
      </section>

      <div className="split split-teacher">
        <section className="glass panel">
          <h2>{t('teacher.createTitle')}</h2>
          <form
            className="stack"
            onSubmit={(e) => create.run(e, async () => {
              setCreatedCode(null);
              const res = await api.createClass(name.trim(), password);
              setName('');
              setPassword('');
              setCreatedCode(res.class.code);
              await load();
            })}
          >
            <label className="field">
              <span>{t('teacher.className')}</span>
              <input required maxLength={100} placeholder={t('teacher.classNamePh')} value={name} onChange={(e) => setName(e.target.value)} />
            </label>
            <label className="field">
              <span>{t('teacher.classPassword')}</span>
              <input required minLength={4} maxLength={64} autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} />
            </label>
            <button type="submit" className="btn btn-primary" disabled={create.busy}>{t('teacher.create')}</button>
            {create.error && <Notice kind="error">{create.error}</Notice>}
            {createdCode && <Notice kind="ok">{t('teacher.created', { code: createdCode })}</Notice>}
          </form>
        </section>

        <section className="glass panel">
          <h2>{t('teacher.classes')}</h2>
          {loadError && <Notice kind="error">{loadError}</Notice>}
          {classes === null && !loadError && <p className="muted">{t('common.loading')}</p>}
          {classes && live.length === 0 && <p className="muted">{t('teacher.noClasses')}</p>}
          <div className="class-grid">
            {live.map((c) => (
              <Link key={c.id} to={`/classes/${c.id}`} className={createdCode === c.code ? 'class-card fresh' : 'class-card'}>
                <strong>{c.name}</strong>
                <span className="class-code mono">{c.code}</span>
                <span className="class-meta">
                  <span>{t('teacher.members', { n: c.memberCount })}</span>
                  <span className={c.open ? 'badge badge-green' : 'badge badge-gray'}>{c.open ? t('teacher.open') : t('teacher.closed')}</span>
                </span>
              </Link>
            ))}
          </div>

          {deleted.length > 0 && (
            <details className="deleted">
              <summary>{t('teacher.deleted')} ({deleted.length})</summary>
              <ul className="class-list">
                {deleted.map((c) => (
                  <li key={c.id} className="class-item">
                    <div>
                      <strong>{c.name}</strong> <span className="mono code-chip">{c.code}</span>
                      <p className="muted small">{t('teacher.members', { n: c.memberCount })}</p>
                    </div>
                    <button
                      type="button"
                      className="btn btn-cream btn-sm"
                      disabled={restore.busy}
                      onClick={() => restore.run(null, async () => {
                        await api.restoreClass(c.id);
                        await load();
                      })}
                    >
                      {t('teacher.restore')}
                    </button>
                  </li>
                ))}
              </ul>
              {restore.error && <Notice kind="error">{restore.error}</Notice>}
            </details>
          )}
        </section>
      </div>

      <section className="glass panel">
        <h2>{t('teacher.tools')}</h2>
        <div className="tool-grid">
          <a className="tool" href="/sim/teacher.html">
            <span className="launch-icon launch-sim"><SimIcon /></span>
            <span><strong>{t('teacher.simTeacher')}</strong><span className="muted small">{t('teacher.simTeacherText')}</span></span>
          </a>
          <a className="tool" href="/game/">
            <span className="launch-icon launch-game"><GameIcon /></span>
            <span><strong>{t('teacher.tryGame')}</strong><span className="muted small">{t('teacher.tryGameText')}</span></span>
          </a>
          <div className="tool disabled" aria-disabled="true">
            <span className="launch-icon launch-soon">
              <svg viewBox="0 0 48 48" aria-hidden="true"><path d="M8 40V22h7v18zm12 0V10h7v30zm12 0V28h7v12z" fill="currentColor" /></svg>
            </span>
            <span><strong>{t('teacher.gameDash')}</strong><span className="badge badge-amber">{t('teacher.soon')}</span></span>
          </div>
        </div>
      </section>
    </Shell>
  );
}
