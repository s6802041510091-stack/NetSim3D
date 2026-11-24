import { useEffect, useRef, useState } from 'react';
import { api, csvUrl, type CsvType, type GameAttempt, type GameResults, type StudentResults } from '../api';
import { Notice } from '../components';
import { formatDate, useI18n, type Lang } from '../i18n';

// Level names as the game shows them (scripts/game_flow.gd TITLES / TITLES_EN).
const LEVEL_NAMES: Record<Lang, string[]> = {
  th: ['เลือกอุปกรณ์เครือข่าย', 'เข้าหัวสาย LAN', 'ตรวจเครือข่ายด้วย ping', 'เปลี่ยนการ์ดเครือข่าย', 'ป้องกันภัยคอมพิวเตอร์', 'ช่วยเหลือระยะไกล'],
  en: ['Choose Devices', 'Crimp LAN Cables', 'Ping Test', 'Replace the NIC', 'Firewall & Antivirus', 'Remote Help'],
};

const fullName = (s: { firstName: string | null; lastName: string | null; email: string }) =>
  `${s.firstName ?? ''} ${s.lastName ?? ''}`.trim() || s.email;

function duration(sec: number): string {
  const s = Math.round(sec);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

function Stars({ n }: { n: number }) {
  if (n >= 4) return <span className="stars rainbow" aria-label="4">★★★</span>;
  return <span className="stars" aria-label={String(n)}>{'★'.repeat(n)}<span className="stars-off">{'★'.repeat(3 - n)}</span></span>;
}

function Score({ total, passed }: { total: number; passed: boolean }) {
  return <span className={passed ? 'score score-pass' : 'score score-fail'}>{total}</span>;
}

export default function GameResultsTab({ classId }: { classId: string }) {
  const { t, lang, errorText } = useI18n();
  const [data, setData] = useState<GameResults | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [level, setLevel] = useState<number | null>(null);
  const [detail, setDetail] = useState<StudentResults | null>(null);

  useEffect(() => {
    let live = true;
    api.gameResults(classId).then(
      (d) => live && setData(d),
      (err) => live && setError(errorText(err)),
    );
    return () => { live = false; };
  }, [classId, errorText]);

  if (error) return <section className="glass panel"><Notice kind="error">{error}</Notice></section>;
  if (!data) return <section className="glass panel"><p className="muted">{t('common.loading')}</p></section>;

  const students = data.students;
  const names = LEVEL_NAMES[lang];

  return (
    <>
      <section className="glass panel">
        <div className="level-tabs" role="tablist">
          <button type="button" role="tab" aria-selected={level === null} className={level === null ? 'chip on' : 'chip'} onClick={() => setLevel(null)}>
            {t('game.levelAll')}
          </button>
          {data.levels.map((l) => (
            <button key={l} type="button" role="tab" aria-selected={level === l} className={level === l ? 'chip on' : 'chip'} onClick={() => setLevel(l)} title={names[l - 1]}>
              {t('game.level', { n: l })}
            </button>
          ))}
        </div>

        {students.length === 0 ? (
          <p className="muted">{t('class.noMembers')}</p>
        ) : level === null ? (
          <Overview data={data} onOpen={setDetail} />
        ) : (
          <LevelView data={data} level={level} name={names[level - 1]} onOpen={setDetail} />
        )}
      </section>

      <CsvCard classId={classId} level={level} />

      {detail && <AttemptsDialog classId={classId} student={detail} onClose={() => setDetail(null)} />}
    </>
  );
}

function Overview({ data, onOpen }: { data: GameResults; onOpen: (s: StudentResults) => void }) {
  const { t, lang } = useI18n();
  return (
    <>
      <p className="muted small">{t('game.hint')}</p>
      <div className="table-wrap">
        <table className="results">
          <thead>
            <tr>
              <th>{t('class.colStudentId')}</th>
              <th>{t('game.colStudent')}</th>
              {data.levels.map((l) => (
                <th key={l} className="num" title={LEVEL_NAMES[lang][l - 1]}>{t('game.level', { n: l })}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.students.map((s) => (
              <tr key={s.id}>
                <td className="mono small">{s.studentId}</td>
                <td>
                  <button type="button" className="link-btn" onClick={() => onOpen(s)}>{fullName(s)}</button>
                  {s.former && <span className="badge badge-gray small-badge">{t('game.former')}</span>}
                </td>
                {data.levels.map((l) => {
                  const x = s.levels[l];
                  return (
                    <td key={l} className="num">
                      {x ? (
                        <span className="cell-score">
                          <Score total={x.best.total} passed={x.best.passed} />
                          <Stars n={x.best.stars} />
                          <span className="muted tiny">×{x.attempts}</span>
                        </span>
                      ) : (
                        <span className="muted">—</span>
                      )}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

function LevelView({ data, level, name, onOpen }: { data: GameResults; level: number; name: string; onOpen: (s: StudentResults) => void }) {
  const { t, lang } = useI18n();
  const rows = data.students.map((s) => ({ s, x: s.levels[level] }));
  const played = rows.filter((r) => r.x);
  const passed = played.filter((r) => r.x!.best.passed).length;
  const avg = played.length ? Math.round(played.reduce((sum, r) => sum + r.x!.best.total, 0) / played.length) : null;
  // Not played first, so the teacher sees who still has to do it.
  const sorted = [...rows].sort((a, b) => Number(Boolean(a.x)) - Number(Boolean(b.x)));

  return (
    <>
      <h2 className="level-name">{t('game.level', { n: level })} · {name}</h2>
      <div className="stat-row">
        <span className="stat">{t('game.played', { n: played.length, total: rows.length })}</span>
        <span className="stat stat-green">{t('game.passedCount', { n: passed })}</span>
        {avg !== null && <span className="stat">{t('game.avgBest', { n: avg })}</span>}
      </div>
      <p className="muted small">{t('game.levelHint')}</p>
      <div className="table-wrap">
        <table className="results">
          <thead>
            <tr>
              <th>{t('class.colStudentId')}</th>
              <th>{t('game.colStudent')}</th>
              <th>{t('game.colStatus')}</th>
              <th className="num">{t('game.colFirst')}</th>
              <th className="num">{t('game.colBest')}</th>
              <th className="num">{t('game.colLast')}</th>
              <th className="num">{t('game.colAttempts')}</th>
              <th>{t('game.colLastPlayed')}</th>
            </tr>
          </thead>
          <tbody>
            {sorted.map(({ s, x }) => (
              <tr key={s.id} className={x ? '' : 'row-idle'}>
                <td className="mono small">{s.studentId}</td>
                <td>
                  <button type="button" className="link-btn" onClick={() => onOpen(s)}>{fullName(s)}</button>
                  {s.former && <span className="badge badge-gray small-badge">{t('game.former')}</span>}
                </td>
                <td>
                  {!x ? (
                    <span className="badge badge-amber">{t('game.notPlayed')}</span>
                  ) : x.best.passed ? (
                    <span className="badge badge-green">{t('game.pass')}</span>
                  ) : (
                    <span className="badge badge-red">{t('game.fail')}</span>
                  )}
                </td>
                <td className="num">{x ? <Score total={x.first.total} passed={x.first.passed} /> : '—'}</td>
                <td className="num">{x ? <><Score total={x.best.total} passed={x.best.passed} /> <Stars n={x.best.stars} /></> : '—'}</td>
                <td className="num">{x ? <Score total={x.last.total} passed={x.last.passed} /> : '—'}</td>
                <td className="num">{x ? x.attempts : 0}</td>
                <td className="small">{x ? formatDate(x.last.finishedAt, lang) : ''}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}

function CsvCard({ classId, level }: { classId: string; level: number | null }) {
  const { t, lang } = useI18n();
  const [type, setType] = useState<CsvType>('attempts');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const options: { value: CsvType; title: string; text: string }[] = [
    { value: 'summary', title: t('csv.summary'), text: t('csv.summaryText') },
    { value: 'attempts', title: t('csv.attempts'), text: t('csv.attemptsText') },
    { value: 'steps', title: t('csv.steps'), text: t('csv.stepsText') },
  ];
  const href = csvUrl(classId, { type, level: level ?? undefined, from: from || undefined, to: to || undefined, lang });

  return (
    <section className="glass panel">
      <h2>{t('csv.title')}</h2>
      <p className="muted small">{t('csv.intro')}</p>
      <div className="csv-types" role="radiogroup">
        {options.map((o) => (
          <label key={o.value} className={type === o.value ? 'csv-type on' : 'csv-type'}>
            <input type="radio" name="csv-type" value={o.value} checked={type === o.value} onChange={() => setType(o.value)} />
            <strong>{o.title}</strong>
            <span className="muted small">{o.text}</span>
          </label>
        ))}
      </div>
      <div className="csv-filters">
        <span className="field">
          <span>{t('csv.level')}</span>
          <span className="filter-value">{level ? t('game.level', { n: level }) : t('game.levelAll')}</span>
        </span>
        <label className="field">
          <span>{t('csv.from')}</span>
          <input type="date" value={from} max={to || undefined} onChange={(e) => setFrom(e.target.value)} />
        </label>
        <label className="field">
          <span>{t('csv.to')}</span>
          <input type="date" value={to} min={from || undefined} onChange={(e) => setTo(e.target.value)} />
        </label>
        <a className="btn btn-primary" href={href} download>
          <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path d="M12 3v11m0 0 4.5-4.5M12 14 7.5 9.5M4 17v3h16v-3" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" /></svg>
          {t('csv.download')}
        </a>
      </div>
    </section>
  );
}

function AttemptsDialog({ classId, student, onClose }: { classId: string; student: StudentResults; onClose: () => void }) {
  const { t, lang, errorText } = useI18n();
  const ref = useRef<HTMLDialogElement>(null);
  const [attempts, setAttempts] = useState<GameAttempt[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    ref.current?.showModal();
    api.gameAttempts(classId, student.id).then((r) => setAttempts(r.attempts), (err) => setError(errorText(err)));
  }, [classId, student.id, errorText]);

  return (
    <dialog ref={ref} className="dialog dialog-wide glass" onClose={onClose} onCancel={onClose}>
      <div className="dialog-head">
        <h2>{t('game.detailTitle', { name: fullName(student) })}</h2>
        <button type="button" className="btn btn-cream btn-sm" onClick={() => ref.current?.close()}>{t('game.close')}</button>
      </div>
      <p className="muted small mono">{student.studentId} · {student.email}</p>
      {error && <Notice kind="error">{error}</Notice>}
      {attempts === null && !error && <p className="muted">{t('common.loading')}</p>}
      {attempts?.length === 0 && <p className="muted">{t('game.noAttempts')}</p>}
      <ol className="attempt-list">
        {attempts?.map((a) => (
          <li key={a.id} className="attempt">
            <div className="attempt-head">
              <strong>{t('game.attemptLine', { level: a.level, n: a.attemptNo })}</strong>
              <span className="muted small">{LEVEL_NAMES[lang][a.level - 1]}</span>
              <span className="attempt-score"><Score total={a.total} passed={a.passed} /> <Stars n={a.stars} /></span>
            </div>
            <p className="muted small">
              {formatDate(a.finishedAt, lang)} · {t('game.timeTaken', { time: duration(a.elapsedSec) })} ·{' '}
              {t('game.parts', { c: a.correctness, p: a.process, t: a.timeScore })} ·{' '}
              {t('game.decisions', { a: a.decisionsCorrect, b: a.decisionsTotal })}
              {a.checkCount !== null && <> · {t('game.checks', { n: a.checkCount })}</>}
            </p>
            <details>
              <summary>{t('game.steps')} · {t('game.mistakes')} ({a.mistakeLog.length || a.mistakes.length})</summary>
              <div className="attempt-body">
                {a.stepTimes.length > 0 && (
                  <ol className="steps">
                    {a.stepTimes.map((s) => {
                      const here = a.mistakeLog.filter((m) => !m.at_end && m.step === s.step);
                      return (
                        <li key={s.step}>
                          <span>{s.step}. {s.name}</span>
                          <span className="mono small">{duration(s.sec)}</span>
                          {here.map((m, i) => <MistakeLine key={i} m={m} />)}
                        </li>
                      );
                    })}
                  </ol>
                )}
                {a.mistakeLog.filter((m) => m.at_end || !a.stepTimes.some((s) => s.step === m.step)).map((m, i) => <MistakeLine key={i} m={m} />)}
                {a.mistakeLog.length === 0 && a.mistakes.length === 0 && <p className="muted small">{t('game.noMistakes')}</p>}
                {a.mistakeLog.length === 0 && a.mistakes.map((m, i) => <p key={i} className="mistake">{m}</p>)}
              </div>
            </details>
          </li>
        ))}
      </ol>
    </dialog>
  );
}

function MistakeLine({ m }: { m: GameAttempt['mistakeLog'][number] }) {
  const { t } = useI18n();
  const when = m.at_end ? t('game.atEnd') : typeof m.at_sec === 'number' ? t('game.atSec', { s: Math.round(m.at_sec) }) : '';
  return (
    <p className="mistake">
      <strong>{m.what || m.text}</strong>
      {m.why && <> — {m.why}</>}
      {when && <span className="muted small"> ({when})</span>}
    </p>
  );
}
