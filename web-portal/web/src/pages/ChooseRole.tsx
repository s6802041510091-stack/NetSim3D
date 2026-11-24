import { Navigate, useNavigate } from 'react-router';
import { api, type Role } from '../api';
import { Notice, Shell, useAction } from '../components';
import { useI18n } from '../i18n';
import { nextStep, useSession } from '../session';

export default function ChooseRole() {
  const { t } = useI18n();
  const { me, setMe } = useSession();
  const navigate = useNavigate();
  const { busy, error, run } = useAction();

  if (me && !me.needsRole) return <Navigate to={nextStep(me) ?? '/lobby'} replace />;

  function choose(role: Role) {
    void run(null, async () => {
      const res = await api.setRole(role);
      setMe(res.me);
      navigate(nextStep(res.me) ?? '/lobby', { replace: true });
    });
  }

  return (
    <Shell>
      <section className="glass panel narrow">
        <h1>{t('role.title')}</h1>
        <p className="muted">{t('role.once')}</p>
        <div className="role-grid">
          <button type="button" className="role-card" disabled={busy} onClick={() => choose('student')}>
            <span className="role-icon role-icon-student" aria-hidden="true">
              <svg viewBox="0 0 48 48"><path d="M24 8 4 18l20 10 16-8v12h4V18z" fill="currentColor" /><path d="M12 25v8c0 3 5.4 6 12 6s12-3 12-6v-8l-12 6z" fill="currentColor" opacity=".75" /></svg>
            </span>
            <strong>{t('role.student')}</strong>
            <span>{t('role.studentText')}</span>
            <span className="btn btn-primary btn-sm">{t('role.choose')}</span>
          </button>
          <button type="button" className="role-card" disabled={busy || !me?.canTeach} onClick={() => choose('teacher')}>
            <span className="role-icon role-icon-teacher" aria-hidden="true">
              <svg viewBox="0 0 48 48"><rect x="6" y="8" width="36" height="24" rx="3" fill="currentColor" opacity=".75" /><circle cx="24" cy="32" r="6" fill="currentColor" /><path d="M12 44c0-6 5.4-9 12-9s12 3 12 9z" fill="currentColor" /></svg>
            </span>
            <strong>{t('role.teacher')}</strong>
            <span>{me?.canTeach ? t('role.teacherText') : t('role.teacherLocked')}</span>
            <span className={me?.canTeach ? 'btn btn-primary btn-sm' : 'btn btn-cream btn-sm'}>{t('role.choose')}</span>
          </button>
        </div>
        {error && <Notice kind="error">{error}</Notice>}
      </section>
    </Shell>
  );
}
