import { useState } from 'react';
import { Navigate, useNavigate } from 'react-router';
import { api } from '../api';
import { Notice, Shell, useAction } from '../components';
import { useI18n } from '../i18n';
import { useSession } from '../session';

export default function Profile() {
  const { t } = useI18n();
  const { me, setMe } = useSession();
  const navigate = useNavigate();
  const firstTime = Boolean(me?.needsProfile);
  const [firstName, setFirstName] = useState(me?.firstName ?? '');
  const [lastName, setLastName] = useState(me?.lastName ?? '');
  const [studentId, setStudentId] = useState(me?.studentId ?? '');
  const [idTouched, setIdTouched] = useState(false);
  const { busy, error, done, run } = useAction();

  if (me && me.role !== 'student') return <Navigate to="/lobby" replace />;

  const idValid = /^\d{13}$/.test(studentId);

  return (
    <Shell>
      <section className="glass panel narrow">
        <h1>{t('profile.title')}</h1>
        <p className="muted">{t('profile.intro')}</p>
        <form
          className="stack"
          onSubmit={(e) => {
            setIdTouched(true);
            if (!idValid) {
              e.preventDefault();
              return;
            }
            void run(e, async () => {
              const res = await api.saveProfile({ firstName: firstName.trim(), lastName: lastName.trim(), studentId });
              setMe(res.me);
              if (firstTime) {
                navigate('/lobby', { replace: true });
                return null;
              }
              return t('profile.saved');
            });
          }}
        >
          <div className="two-col">
            <label className="field">
              <span>{t('profile.first')}</span>
              <input required maxLength={100} autoComplete="given-name" value={firstName} onChange={(e) => setFirstName(e.target.value)} />
            </label>
            <label className="field">
              <span>{t('profile.last')}</span>
              <input required maxLength={100} autoComplete="family-name" value={lastName} onChange={(e) => setLastName(e.target.value)} />
            </label>
          </div>
          <label className="field">
            <span>{t('profile.studentId')}</span>
            <input
              required
              inputMode="numeric"
              maxLength={13}
              className="mono"
              aria-invalid={idTouched && !idValid}
              aria-describedby="sid-hint"
              value={studentId}
              onChange={(e) => setStudentId(e.target.value.replace(/\D/g, '').slice(0, 13))}
              onBlur={() => setIdTouched(true)}
            />
            <small id="sid-hint" className={idTouched && !idValid ? 'field-error' : 'hint'}>
              {idTouched && !idValid ? t('profile.idInvalid') : t('profile.idHint')}
              <span className="count">{studentId.length}/13</span>
            </small>
          </label>
          <label className="field">
            <span>{t('profile.email')}</span>
            <input value={me?.email ?? ''} readOnly disabled />
          </label>
          <button type="submit" className="btn btn-primary" disabled={busy}>{t('profile.save')}</button>
          {error && <Notice kind="error">{error}</Notice>}
          {done && <Notice kind="ok">{done}</Notice>}
        </form>
      </section>
    </Shell>
  );
}
