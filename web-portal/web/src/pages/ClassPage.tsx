import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { api, type Member, type TeacherClass } from '../api';
import { ConfirmDialog, Notice, Shell, useAction } from '../components';
import { formatDate, useI18n } from '../i18n';

export default function ClassPage() {
  const { id = '' } = useParams();
  const { t, lang, errorText } = useI18n();
  const navigate = useNavigate();
  const [cls, setCls] = useState<TeacherClass | null>(null);
  const [members, setMembers] = useState<Member[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [copied, setCopied] = useState(false);
  const [removing, setRemoving] = useState<Member | null>(null);
  const [deleting, setDeleting] = useState(false);
  const rename = useAction();
  const password = useAction();
  const toggle = useAction();
  const remove = useAction();
  const del = useAction();

  const load = useCallback(async () => {
    try {
      const res = await api.classDetail(id);
      setCls(res.class);
      setMembers(res.members);
      setName(res.class.name);
      setLoadError(null);
    } catch (err) {
      setLoadError(errorText(err));
    }
  }, [id, errorText]);

  useEffect(() => {
    void load();
  }, [load]);

  async function copyCode() {
    if (!cls) return;
    try {
      await navigator.clipboard.writeText(cls.code);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {
      // clipboard blocked: the code is on screen to copy by hand
    }
  }

  const fullName = (m: Member) => `${m.firstName ?? ''} ${m.lastName ?? ''}`.trim() || m.email;

  return (
    <Shell wide>
      <p><Link to="/lobby" className="back-link">← {t('class.back')}</Link></p>
      {loadError && <section className="glass panel"><Notice kind="error">{loadError}</Notice></section>}
      {!cls && !loadError && <section className="glass panel"><p className="muted">{t('common.loading')}</p></section>}

      {cls && (
        <>
          {cls.deletedAt && (
            <div className="banner">
              <span>{t('class.deletedBanner')}</span>
              <button
                type="button"
                className="btn btn-cream btn-sm"
                disabled={del.busy}
                onClick={() => del.run(null, async () => {
                  await api.restoreClass(cls.id);
                  await load();
                })}
              >
                {t('teacher.restore')}
              </button>
            </div>
          )}

          <section className="glass panel class-head">
            <div>
              <h1>{cls.name}</h1>
              <span className={cls.open ? 'badge badge-green' : 'badge badge-gray'}>{cls.open ? t('class.openState') : t('class.closedState')}</span>
            </div>
            <div className="code-box">
              <span className="code-label">Class ID</span>
              <span className="code-big mono">{cls.code}</span>
              <button type="button" className="btn btn-cream btn-sm" onClick={copyCode}>{copied ? t('class.copied') : t('class.copy')}</button>
              <p className="muted small">{t('class.share')}</p>
            </div>
          </section>

          <div className="split">
            <section className="glass panel">
              <h2>{t('class.members', { n: members.length })}</h2>
              {members.length === 0 ? (
                <p className="muted">{t('class.noMembers')}</p>
              ) : (
                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>{t('class.colStudentId')}</th>
                        <th>{t('class.colName')}</th>
                        <th>{t('class.colEmail')}</th>
                        <th>{t('class.colJoined')}</th>
                        <th><span className="sr-only">{t('class.remove')}</span></th>
                      </tr>
                    </thead>
                    <tbody>
                      {members.map((m) => (
                        <tr key={m.id}>
                          <td className="mono">{m.studentId}</td>
                          <td>{fullName(m)}</td>
                          <td className="small">{m.email}</td>
                          <td className="small">{formatDate(m.joinedAt, lang)}</td>
                          <td><button type="button" className="btn btn-ghost btn-sm" onClick={() => setRemoving(m)}>{t('class.remove')}</button></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              {remove.error && <Notice kind="error">{remove.error}</Notice>}
            </section>

            <section className="glass panel">
              <h2>{t('class.settings')}</h2>
              <fieldset disabled={Boolean(cls.deletedAt)} className="stack">
                <form
                  className="inline-form"
                  onSubmit={(e) => rename.run(e, async () => {
                    setCls((await api.updateClass(cls.id, { name: name.trim() })).class);
                    return t('class.nameSaved');
                  })}
                >
                  <label className="field grow">
                    <span>{t('class.name')}</span>
                    <input required maxLength={100} value={name} onChange={(e) => setName(e.target.value)} />
                  </label>
                  <button type="submit" className="btn btn-cream" disabled={rename.busy}>{t('class.saveName')}</button>
                </form>
                {rename.error && <Notice kind="error">{rename.error}</Notice>}
                {rename.done && <Notice kind="ok">{rename.done}</Notice>}

                <form
                  className="inline-form"
                  onSubmit={(e) => password.run(e, async () => {
                    await api.updateClass(cls.id, { password: newPassword });
                    setNewPassword('');
                    return t('class.passwordChanged');
                  })}
                >
                  <label className="field grow">
                    <span>{t('class.newPassword')}</span>
                    <input required minLength={4} maxLength={64} autoComplete="new-password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} />
                  </label>
                  <button type="submit" className="btn btn-cream" disabled={password.busy}>{t('class.changePassword')}</button>
                </form>
                {password.error && <Notice kind="error">{password.error}</Notice>}
                {password.done && <Notice kind="ok">{password.done}</Notice>}

                <div className="toggle-row">
                  <span>{cls.open ? t('class.openState') : t('class.closedState')}</span>
                  <button
                    type="button"
                    className="btn btn-cream btn-sm"
                    disabled={toggle.busy}
                    onClick={() => toggle.run(null, async () => setCls((await api.updateClass(cls.id, { open: !cls.open })).class))}
                  >
                    {cls.open ? t('class.close') : t('class.reopen')}
                  </button>
                </div>
                {toggle.error && <Notice kind="error">{toggle.error}</Notice>}

                <div className="danger-zone">
                  <h3>{t('class.danger')}</h3>
                  <p className="muted small">{t('class.deleteText')}</p>
                  <button type="button" className="btn btn-danger btn-sm" onClick={() => setDeleting(true)}>{t('class.delete')}</button>
                  {del.error && <Notice kind="error">{del.error}</Notice>}
                </div>
              </fieldset>
            </section>
          </div>

          <ConfirmDialog
            open={removing !== null}
            title={t('class.removeTitle')}
            text={removing ? t('class.removeText', { name: fullName(removing) }) : ''}
            confirmLabel={t('class.remove')}
            danger
            busy={remove.busy}
            onCancel={() => setRemoving(null)}
            onConfirm={() => remove.run(null, async () => {
              if (removing) await api.removeMember(cls.id, removing.id);
              setRemoving(null);
              await load();
            })}
          />
          <ConfirmDialog
            open={deleting}
            title={t('class.deleteTitle', { name: cls.name })}
            text={t('class.deleteText')}
            confirmLabel={t('class.delete')}
            danger
            busy={del.busy}
            onCancel={() => setDeleting(false)}
            onConfirm={() => del.run(null, async () => {
              await api.deleteClass(cls.id);
              setDeleting(false);
              navigate('/lobby');
            })}
          />
        </>
      )}
    </Shell>
  );
}
