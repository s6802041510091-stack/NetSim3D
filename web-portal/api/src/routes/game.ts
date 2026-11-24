import { Router, type Response } from 'express';
import { z } from 'zod';
import { currentUser, requireStudent, requireTeacher } from '../auth.ts';
import { cell, digitsCell, toCsv } from '../csv.ts';
import { HttpError, parse } from '../errors.ts';
import type { AppOptions } from './me.ts';

// Must match the game (scripts/core/mission_score.gd and game_progress.gd).
const LEVELS = [1, 2, 3, 4, 5, 6];
const PASS_SCORE = 50;
const STAR_THRESHOLDS = [50, 60, 70, 80];
const HISTORY_LIMIT = 30;

const starsFor = (total: number) => STAR_THRESHOLDS.filter((t) => total >= t).length;
const int = (min: number, max: number) => z.number().int().min(min).max(max);

// What GameProgress.record_attempt builds: MissionScore.to_dict() + the mission's extras.
const resultSchema = z.looseObject({
  total: int(0, 100),
  correctness: int(0, 30),
  process: int(0, 50),
  time: int(0, 20),
  stars: int(0, 4),
  passed: z.boolean(),
  elapsed_sec: z.number().min(0).max(86400),
  decisions_correct: int(0, 100000),
  decisions_total: int(0, 100000),
  mistakes: z.array(z.string().max(1000)).max(300).default([]),
  step_times: z.array(z.looseObject({ step: z.number(), name: z.string().max(500), sec: z.number().min(0) })).max(200).default([]),
  mistake_log: z.array(z.record(z.string(), z.unknown())).max(500).default([]),
  check_count: int(0, 1000000).nullish(),
});

const attemptSchema = z.object({
  clientId: z.string().regex(/^[A-Za-z0-9_-]{8,64}$/),
  level: int(1, 6),
  // Seconds since the level ended (more than 0 when the game sends a queued attempt later).
  ageSec: z.number().min(0).max(30 * 86400).default(0),
  result: resultSchema,
});

type AttemptRow = {
  id: string;
  studentId: string;
  level: number;
  total: number;
  correctness: number;
  process: number;
  timeScore: number;
  stars: number;
  passed: boolean;
  elapsedSec: number;
  decisionsCorrect: number;
  decisionsTotal: number;
  checkCount: number | null;
  mistakes: string[];
  stepTimes: { step: number; name: string; sec: number }[];
  mistakeLog: Record<string, unknown>[];
  result: Record<string, unknown>;
  finishedAt: Date;
};

const ATTEMPT_COLUMNS = `a.id, a.student_id AS "studentId", a.level, a.total, a.correctness, a.process,
  a.time_score AS "timeScore", a.stars, a.passed, a.elapsed_sec AS "elapsedSec",
  a.decisions_correct AS "decisionsCorrect", a.decisions_total AS "decisionsTotal", a.check_count AS "checkCount",
  a.mistakes, a.step_times AS "stepTimes", a.mistake_log AS "mistakeLog", a.result, a.finished_at AS "finishedAt"`;

type Numbered = AttemptRow & { attemptNo: number };

/** Numbers each student's attempts per level 1, 2, 3 … in the order they were played. */
function numbered(rows: AttemptRow[]): Numbered[] {
  const seen = new Map<string, number>();
  return rows.map((r) => {
    const key = `${r.studentId}:${r.level}`;
    const n = (seen.get(key) ?? 0) + 1;
    seen.set(key, n);
    return { ...r, attemptNo: n };
  });
}

function localTime(timeZone: string) {
  const fmt = new Intl.DateTimeFormat('sv-SE', {
    timeZone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
  });
  return (d: Date) => fmt.format(d); // "2026-11-25 09:41:07"
}

type Brief = { total: number; stars: number; passed: boolean; finishedAt: Date };
type LevelSummary = { attempts: number; first: Brief; best: Brief; last: Brief };

function summarize(attempts: Numbered[]): Record<string, LevelSummary> {
  const out: Record<string, LevelSummary> = {};
  for (const a of attempts) {
    const brief = { total: a.total, stars: a.stars, passed: a.passed, finishedAt: a.finishedAt };
    const s = out[a.level];
    if (!s) {
      out[a.level] = { attempts: 1, first: brief, best: brief, last: brief };
      continue;
    }
    s.attempts++;
    if (a.total > s.best.total) s.best = brief;
    s.last = brief;
  }
  return out;
}

type Person = { id: string; studentId: string | null; firstName: string | null; lastName: string | null; email: string; former: boolean };

export function gameRoutes({ pool, timeZone = 'Asia/Bangkok' }: AppOptions): Router {
  const r = Router();
  const toLocal = localTime(timeZone);

  async function ownClass(teacherId: string, classId: string) {
    const { rows } = await pool.query<{ id: string; code: string; name: string }>(
      'SELECT id, code, name FROM classes WHERE id = $1 AND teacher_id = $2',
      [classId, teacherId],
    );
    if (!rows[0]) throw new HttpError(404, 'class_not_found');
    return rows[0];
  }

  /** Current members plus anyone who left but has attempts in this class (marked former). */
  async function classPeople(classId: string): Promise<Person[]> {
    const { rows } = await pool.query<Person>(
      `SELECT u.id, u.student_id AS "studentId", u.first_name AS "firstName", u.last_name AS "lastName", u.email,
              NOT EXISTS (SELECT 1 FROM enrollments e WHERE e.class_id = $1 AND e.student_id = u.id) AS former
       FROM users u
       WHERE EXISTS (SELECT 1 FROM enrollments e WHERE e.class_id = $1 AND e.student_id = u.id)
          OR EXISTS (SELECT 1 FROM game_attempts a WHERE a.class_id = $1 AND a.student_id = u.id)
       ORDER BY u.student_id NULLS LAST, u.email`,
      [classId],
    );
    return rows;
  }

  async function classAttempts(classId: string): Promise<Numbered[]> {
    const { rows } = await pool.query<AttemptRow>(
      `SELECT ${ATTEMPT_COLUMNS} FROM game_attempts a WHERE a.class_id = $1 ORDER BY a.finished_at, a.received_at`,
      [classId],
    );
    return numbered(rows);
  }

  // ---------- the game ----------

  r.post('/game/attempts', async (req, res) => {
    const student = requireStudent(req);
    const body = parse(attemptSchema, req.body);
    const s = body.result;
    if (s.total !== s.correctness + s.process + s.time || s.stars !== starsFor(s.total) || s.passed !== s.total >= PASS_SCORE) {
      throw new HttpError(400, 'inconsistent_score');
    }
    // The class the student is working in now (only if still a member of a live class).
    const { rows: cls } = await pool.query<{ id: string }>(
      `SELECT c.id FROM users u JOIN classes c ON c.id = u.active_class_id AND c.deleted_at IS NULL
       JOIN enrollments e ON e.class_id = c.id AND e.student_id = u.id WHERE u.id = $1`,
      [student.id],
    );
    const inserted = await pool.query<{ id: string }>(
      `INSERT INTO game_attempts (student_id, class_id, client_id, level, total, correctness, process, time_score, stars, passed,
         elapsed_sec, decisions_correct, decisions_total, check_count, mistakes, step_times, mistake_log, result, finished_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, now() - make_interval(secs => $19))
       ON CONFLICT (student_id, client_id) DO NOTHING RETURNING id`,
      [
        student.id, cls[0]?.id ?? null, body.clientId, body.level, s.total, s.correctness, s.process, s.time, s.stars, s.passed,
        s.elapsed_sec, s.decisions_correct, s.decisions_total, s.check_count ?? null,
        JSON.stringify(s.mistakes), JSON.stringify(s.step_times), JSON.stringify(s.mistake_log), JSON.stringify(s), body.ageSec,
      ],
    );
    const { rows } = await pool.query<{ id: string; attemptNo: number; classId: string | null }>(
      `SELECT a.id, a.class_id AS "classId",
              (SELECT count(*)::int FROM game_attempts b WHERE b.student_id = a.student_id AND b.level = a.level
                 AND (b.finished_at, b.received_at) <= (a.finished_at, a.received_at)) AS "attemptNo"
       FROM game_attempts a WHERE a.student_id = $1 AND a.client_id = $2`,
      [student.id, body.clientId],
    );
    res.status(inserted.rowCount ? 201 : 200).json({ saved: true, duplicate: !inserted.rowCount, attempt: rows[0] });
  });

  // The student's results in the same shape as the game's progress.json, so the game's
  // menu (stars, unlocking) and its progress page work from the server copy unchanged.
  r.get('/game/progress', async (req, res) => {
    const student = requireStudent(req, { profile: false });
    const { rows } = await pool.query<AttemptRow>(
      `SELECT ${ATTEMPT_COLUMNS} FROM game_attempts a WHERE a.student_id = $1 ORDER BY a.level, a.finished_at, a.received_at`,
      [student.id],
    );
    const progress: Record<string, Record<string, unknown>> = {};
    for (const level of LEVELS) {
      const mine = rows.filter((a) => a.level === level);
      if (!mine.length) continue;
      // The game writes local time without a zone, e.g. "2026-11-25T09:41:07".
      const local = (a: AttemptRow) => toLocal(a.finishedAt).replace(' ', 'T');
      const best = mine.reduce((b, a) => (a.total > b.total ? a : b));
      const last = mine[mine.length - 1];
      progress[level] = {
        attempts: mine.length,
        best_total: best.total,
        best_stars: best.stars,
        last: { ...last.result, finished_at: local(last) },
        history: mine.slice(-HISTORY_LIMIT).map((a) => ({
          total: a.total, stars: a.stars, passed: a.passed, correctness: a.correctness, process: a.process, time: a.timeScore,
          elapsed_sec: a.elapsedSec, decisions_correct: a.decisionsCorrect, decisions_total: a.decisionsTotal,
          mistakes: a.mistakes, finished_at: local(a), step_times: a.stepTimes, mistake_log: a.mistakeLog,
        })),
      };
    }
    res.json({ progress });
  });

  // ---------- teachers ----------

  r.get('/classes/:id/game-results', async (req, res) => {
    const teacher = await requireTeacher(pool, req);
    const { id } = parse(z.object({ id: z.uuid() }), req.params);
    await ownClass(teacher.id, id);
    const [people, attempts] = await Promise.all([classPeople(id), classAttempts(id)]);
    res.json({
      levels: LEVELS,
      passScore: PASS_SCORE,
      students: people.map((p) => ({ ...p, levels: summarize(attempts.filter((a) => a.studentId === p.id)) })),
    });
  });

  r.get('/classes/:id/game-attempts', async (req, res) => {
    const teacher = await requireTeacher(pool, req);
    const { id } = parse(z.object({ id: z.uuid() }), req.params);
    const { studentId } = parse(z.object({ studentId: z.uuid() }), req.query);
    await ownClass(teacher.id, id);
    const attempts = (await classAttempts(id)).filter((a) => a.studentId === studentId);
    res.json({
      attempts: attempts.map(({ result: _result, ...a }) => a).reverse(),
    });
  });

  r.get('/classes/:id/export.csv', async (req, res) => {
    const teacher = await requireTeacher(pool, req);
    const { id } = parse(z.object({ id: z.uuid() }), req.params);
    const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
    const q = parse(
      z.object({
        type: z.enum(['summary', 'attempts', 'steps']).default('attempts'),
        level: z.coerce.number().int().min(1).max(6).optional(),
        from: date.optional(),
        to: date.optional(),
        lang: z.enum(['th', 'en']).default('th'),
      }),
      req.query,
    );
    const cls = await ownClass(teacher.id, id);
    const people = await classPeople(id);
    const byId = new Map(people.map((p) => [p.id, p]));
    const attempts = (await classAttempts(id)).filter((a) => {
      const day = toLocal(a.finishedAt).slice(0, 10);
      return (!q.level || a.level === q.level) && (!q.from || day >= q.from) && (!q.to || day <= q.to);
    });
    const H = HEADERS[q.lang];
    const personCells = (p: Person | undefined) => [digitsCell(p?.studentId ?? null), cell(p?.firstName), cell(p?.lastName), cell(p?.email)];
    let header: string[];
    let rows: string[][];

    if (q.type === 'summary') {
      const levels = q.level ? [q.level] : LEVELS;
      header = [...H.person, ...levels.flatMap((l) => H.levelSummary.map((h) => h.replace('{n}', String(l))))];
      rows = people.map((p) => {
        const s = summarize(attempts.filter((a) => a.studentId === p.id));
        return [
          ...personCells(p),
          ...levels.flatMap((l) => {
            const x = s[l];
            return x ? [cell(x.first.total), cell(x.best.total), cell(x.last.total), cell(x.attempts)] : ['', '', '', '0'];
          }),
        ];
      });
    } else if (q.type === 'attempts') {
      header = [...H.person, ...H.attempt];
      rows = attempts.map((a) => [
        ...personCells(byId.get(a.studentId)),
        cell(a.level), cell(a.attemptNo), cell(toLocal(a.finishedAt)), cell(a.elapsedSec),
        cell(a.total), cell(a.correctness), cell(a.process), cell(a.timeScore), cell(a.stars), cell(a.passed ? H.yes : H.no),
        cell(a.decisionsCorrect), cell(a.decisionsTotal), cell(a.checkCount), cell(a.mistakes.join(' | ')),
      ]);
    } else {
      header = [...H.person, ...H.step];
      rows = [];
      for (const a of attempts) {
        const base = [...personCells(byId.get(a.studentId)), cell(a.level), cell(a.attemptNo), cell(toLocal(a.finishedAt))];
        const log = a.mistakeLog;
        const used = new Set<number>();
        for (const s of a.stepTimes) {
          const here = log.filter((m, i) => !m.at_end && Number(m.step) === s.step && !used.has(i) && used.add(i));
          rows.push([...base, cell(s.step), cell(s.name), cell(s.sec), cell(here.length), cell(here.map(mistakeText(H)).join(' | '))]);
        }
        const rest = log.filter((_m, i) => !used.has(i));
        if (rest.length) rows.push([...base, '', cell(H.afterSteps), '', cell(rest.length), cell(rest.map(mistakeText(H)).join(' | '))]);
      }
    }

    const day = toLocal(new Date()).slice(0, 10);
    sendCsv(res, `netsim-${cls.code}-${q.type}-${day}.csv`, toCsv(header, rows));
  });

  return r;
}

function mistakeText(H: (typeof HEADERS)['th']) {
  return (m: Record<string, unknown>) => {
    const what = String(m.what ?? m.text ?? '').trim();
    const why = String(m.why ?? '').trim();
    const at = typeof m.at_sec === 'number' ? ` (${H.atSec.replace('{s}', String(Math.round(m.at_sec)))})` : '';
    return `${what}${why ? ` — ${why}` : ''}${at}`;
  };
}

function sendCsv(res: Response, filename: string, body: string) {
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  res.setHeader('Cache-Control', 'no-store');
  res.send(body);
}

const HEADERS = {
  th: {
    person: ['รหัสนักศึกษา', 'ชื่อ', 'นามสกุล', 'อีเมล'],
    levelSummary: ['ด่าน {n} ครั้งแรก', 'ด่าน {n} ดีที่สุด', 'ด่าน {n} ล่าสุด', 'ด่าน {n} จำนวนครั้ง'],
    attempt: ['ด่าน', 'ครั้งที่', 'วันเวลาจบ', 'เวลาที่ใช้ (วินาที)', 'คะแนนรวม (100)', 'ความถูกต้อง (30)', 'กระบวนการ (50)', 'เวลา (20)',
      'ดาว', 'ผ่าน', 'ตัดสินใจถูก', 'ตัดสินใจทั้งหมด', 'จำนวนครั้งที่ตรวจ', 'จุดที่ผิดพลาด'],
    step: ['ด่าน', 'ครั้งที่', 'วันเวลาจบ', 'ขั้นที่', 'ชื่อขั้น', 'วินาทีที่ใช้', 'จำนวนจุดที่ผิด', 'จุดที่ผิด'],
    yes: 'ผ่าน',
    no: 'ไม่ผ่าน',
    afterSteps: 'ไม่ระบุขั้น / ตอนจบด่าน',
    atSec: 'วินาทีที่ {s}',
  },
  en: {
    person: ['Student ID', 'First name', 'Last name', 'Email'],
    levelSummary: ['Level {n} first', 'Level {n} best', 'Level {n} last', 'Level {n} attempts'],
    attempt: ['Level', 'Attempt', 'Finished', 'Time taken (s)', 'Total (100)', 'Correctness (30)', 'Process (50)', 'Time (20)',
      'Stars', 'Passed', 'Right decisions', 'All decisions', 'Checks', 'Mistakes'],
    step: ['Level', 'Attempt', 'Finished', 'Step', 'Step name', 'Seconds', 'Mistakes in step', 'What went wrong'],
    yes: 'yes',
    no: 'no',
    afterSteps: 'No step / at the end',
    atSec: 'at {s} s',
  },
};
