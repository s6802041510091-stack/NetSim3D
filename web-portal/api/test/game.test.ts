import assert from 'node:assert/strict';
import { after, beforeEach, describe, test } from 'node:test';
import request from 'supertest';
import type { Pool } from '../src/db.ts';
import { closeDb, freshDb, login, makeApp, student, TEACHER2, teacher } from './helpers.ts';

let db: Pool;
let app: ReturnType<typeof makeApp>;
type Agent = Awaited<ReturnType<typeof student>>;

beforeEach(async () => {
  db = await freshDb();
  app = makeApp(db);
});
after(closeDb);

let nextClientId = 0;
const cid = () => `attempt-${Date.now()}-${nextClientId++}`;

/** A result like GameProgress.record_attempt builds (MissionScore.to_dict() + extras). */
function result(correctness = 20, process = 40, time = 15) {
  const total = correctness + process + time;
  return {
    correctness, process, time, total,
    passed: total >= 50,
    stars: [50, 60, 70, 80].filter((t) => total >= t).length,
    elapsed_sec: 312.4,
    decisions_correct: 8,
    decisions_total: 10,
    mistakes: ['ตั้ง Gateway ผิด'],
    step_times: [{ step: 1, name: 'หยิบสาย LAN', sec: 40.2 }, { step: 2, name: 'ตั้งค่า IP', sec: 120 }],
    mistake_log: [
      { text: 'ตั้ง Gateway ผิด', what: 'ตั้ง Gateway ผิด', why: 'Gateway ต้องเป็น 192.168.1.1', step: 2, step_name: 'ตั้งค่า IP', at_sec: 95.3, at_end: false },
      { text: 'ลืมทดสอบ ping', what: 'ลืมทดสอบ ping', why: '', at_end: true },
    ],
    check_count: 3,
    scored_reasons: { gateway: false },
  };
}

async function classWithStudent() {
  const t = await teacher(app);
  const cls = (await t.post('/api/classes').send({ name: 'ปวช.3/1', password: 'net1234' }).expect(201)).body.class;
  const s = await student(app, 's@test.ac.th');
  await s.post('/api/classes/join').send({ code: cls.code, password: 'net1234' }).expect(200);
  return { t, s, cls };
}

const send = (s: Agent, level: number, r = result(), extra: Record<string, unknown> = {}) =>
  s.post('/api/game/attempts').send({ clientId: cid(), level, result: r, ...extra });

describe('game sends attempts', () => {
  test('saved under the active class, numbered per level', async () => {
    const { s, cls } = await classWithStudent();
    const first = await send(s, 1).expect(201);
    assert.equal(first.body.attempt.attemptNo, 1);
    assert.equal(first.body.attempt.classId, cls.id);
    assert.equal((await send(s, 1, result(30, 50, 20)).expect(201)).body.attempt.attemptNo, 2);
    assert.equal((await send(s, 2).expect(201)).body.attempt.attemptNo, 1);
  });

  test('sending the same attempt twice (offline retry) stores it once', async () => {
    const { s } = await classWithStudent();
    const body = { clientId: 'retry-attempt-1', level: 3, result: result() };
    await s.post('/api/game/attempts').send(body).expect(201);
    const again = await s.post('/api/game/attempts').send(body).expect(200);
    assert.equal(again.body.duplicate, true);
    const { rows } = await db.query('SELECT count(*)::int AS n FROM game_attempts');
    assert.equal(rows[0].n, 1);
  });

  test('a score that does not add up is refused', async () => {
    const { s } = await classWithStudent();
    const bad = { ...result(), total: 99 };
    assert.equal((await send(s, 1, bad).expect(400)).body.error, 'inconsistent_score');
    await send(s, 1, { ...result(), stars: 4 }).expect(400);
    await send(s, 1, { ...result(), correctness: 31, total: 86 }).expect(400);
    await send(s, 7).expect(400);
  });

  test('only logged-in students with a profile can send', async () => {
    const { t } = await classWithStudent();
    await request(app).post('/api/game/attempts').send({ clientId: cid(), level: 1, result: result() }).expect(401);
    assert.equal((await t.post('/api/game/attempts').send({ clientId: cid(), level: 1, result: result() }).expect(403)).body.error, 'student_only');
    const noProfile = await login(app, 'np@test.ac.th');
    await noProfile.post('/api/me/role').send({ role: 'student' });
    await noProfile.post('/api/game/attempts').send({ clientId: cid(), level: 1, result: result() }).expect(403);
  });

  test('a queued attempt keeps the time it was played', async () => {
    const { s, t, cls } = await classWithStudent();
    await send(s, 1, result(10, 30, 10)).expect(201); // played now
    await send(s, 1, result(30, 50, 20), { ageSec: 3600 }).expect(201); // played an hour ago, sent now
    const sid = (await s.get('/api/me')).body.me.id;
    const list = (await t.get(`/api/classes/${cls.id}/game-attempts?studentId=${sid}`).expect(200)).body.attempts;
    // newest first: the one played now is attempt 2
    assert.equal(list[0].attemptNo, 2);
    assert.equal(list[0].total, 50);
    assert.equal(list[1].total, 100);
  });

  test('progress comes back in the shape of the game progress.json', async () => {
    const { s } = await classWithStudent();
    await send(s, 1, result(10, 30, 10));
    await send(s, 1, result(30, 50, 20));
    await send(s, 1, result(20, 40, 15));
    const p = (await s.get('/api/game/progress').expect(200)).body.progress;
    assert.deepEqual(Object.keys(p), ['1']);
    assert.equal(p['1'].attempts, 3);
    assert.equal(p['1'].best_total, 100);
    assert.equal(p['1'].best_stars, 4);
    assert.equal(p['1'].history.length, 3);
    assert.equal(p['1'].history[2].total, 75);
    assert.equal(p['1'].history[2].time, 15);
    assert.match(p['1'].history[0].finished_at, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/);
    assert.deepEqual(p['1'].last.scored_reasons, { gateway: false });
    assert.equal(p['1'].last.check_count, 3);
  });

  test('a student without an active class still keeps the attempt', async () => {
    const s = await student(app, 'alone@test.ac.th');
    const res = await send(s, 1).expect(201);
    assert.equal(res.body.attempt.classId, null);
    assert.equal((await s.get('/api/game/progress')).body.progress['1'].attempts, 1);
  });
});

describe('teacher game results', () => {
  test('first, best and last per level; students who have not played are listed', async () => {
    const { t, s, cls } = await classWithStudent();
    const idle = await student(app, 'idle@test.ac.th');
    await idle.post('/api/classes/join').send({ code: cls.code, password: 'net1234' });
    await send(s, 1, result(10, 30, 10));
    await send(s, 1, result(30, 50, 20));
    await send(s, 1, result(20, 40, 15));
    const body = (await t.get(`/api/classes/${cls.id}/game-results`).expect(200)).body;
    assert.deepEqual(body.levels, [1, 2, 3, 4, 5, 6]);
    assert.equal(body.students.length, 2);
    const played = body.students.find((x: { email: string }) => x.email === 's@test.ac.th');
    assert.equal(played.levels['1'].attempts, 3);
    assert.equal(played.levels['1'].first.total, 50);
    assert.equal(played.levels['1'].best.total, 100);
    assert.equal(played.levels['1'].last.total, 75);
    const notYet = body.students.find((x: { email: string }) => x.email === 'idle@test.ac.th');
    assert.deepEqual(notYet.levels, {});
  });

  test('a removed student still shows (marked former) with the attempts made in the class', async () => {
    const { t, s, cls } = await classWithStudent();
    await send(s, 2);
    const sid = (await s.get('/api/me')).body.me.id;
    await t.delete(`/api/classes/${cls.id}/members/${sid}`).expect(200);
    const body = (await t.get(`/api/classes/${cls.id}/game-results`)).body;
    assert.equal(body.students[0].former, true);
    assert.equal(body.students[0].levels['2'].attempts, 1);
  });

  test("other teachers and students cannot read a class's results", async () => {
    const { s, cls } = await classWithStudent();
    const other = await teacher(app, TEACHER2);
    await other.get(`/api/classes/${cls.id}/game-results`).expect(404);
    await other.get(`/api/classes/${cls.id}/export.csv`).expect(404);
    await s.get(`/api/classes/${cls.id}/game-results`).expect(403);
  });

  test('attempt detail has step times and mistakes', async () => {
    const { t, s, cls } = await classWithStudent();
    await send(s, 2);
    const sid = (await s.get('/api/me')).body.me.id;
    const a = (await t.get(`/api/classes/${cls.id}/game-attempts?studentId=${sid}`).expect(200)).body.attempts[0];
    assert.equal(a.stepTimes.length, 2);
    assert.equal(a.mistakeLog[0].why, 'Gateway ต้องเป็น 192.168.1.1');
    assert.equal(a.result, undefined);
  });
});

describe('CSV export', () => {
  async function csv(t: Agent, classId: string, query: string) {
    const res = await t.get(`/api/classes/${classId}/export.csv?${query}`).buffer(true).parse((r, cb) => {
      let data = '';
      r.setEncoding('utf8');
      r.on('data', (c: string) => { data += c; });
      r.on('end', () => cb(null, data));
    }).expect(200);
    assert.match(res.headers['content-type'], /text\/csv/);
    assert.match(res.headers['content-disposition'], /attachment; filename="netsim-[A-Z0-9]{6}-/);
    const text = res.body as string;
    assert.equal(text.charCodeAt(0), 0xfeff, 'starts with a BOM for Excel');
    return text.slice(1).trimEnd().split('\r\n');
  }

  test('attempts: one row per attempt, student ID kept as text', async () => {
    const { t, s, cls } = await classWithStudent();
    await send(s, 1);
    await send(s, 1, result(30, 50, 20));
    const lines = await csv(t, cls.id, 'type=attempts');
    assert.equal(lines.length, 3);
    assert.match(lines[0], /^รหัสนักศึกษา,ชื่อ,นามสกุล,อีเมล,ด่าน,ครั้งที่,วันเวลาจบ/);
    assert.match(lines[1], /^"=""\d{13}""",สมชาย,ใจดี,s@test\.ac\.th,1,1,\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},312\.4,75,20,40,15,3,ผ่าน,8,10,3,ตั้ง Gateway ผิด$/);
    assert.match(lines[2], /,1,2,.*,100,30,50,20,4,ผ่าน,/);
  });

  test('steps: one row per step, mistakes put on their step', async () => {
    const { t, s, cls } = await classWithStudent();
    await send(s, 4);
    const lines = await csv(t, cls.id, 'type=steps');
    assert.equal(lines.length, 4); // header + 2 steps + end-of-level mistakes
    assert.match(lines[1], /,4,1,.*,1,หยิบสาย LAN,40\.2,0,$/);
    assert.match(lines[2], /,2,ตั้งค่า IP,120,1,ตั้ง Gateway ผิด — Gateway ต้องเป็น 192\.168\.1\.1 \(วินาทีที่ 95\)$/);
    assert.match(lines[3], /,,ไม่ระบุขั้น \/ ตอนจบด่าน,,1,ลืมทดสอบ ping$/);
  });

  test('summary: first, best, last and count per level for every student', async () => {
    const { t, s, cls } = await classWithStudent();
    await send(s, 1, result(10, 30, 10));
    await send(s, 1, result(30, 50, 20));
    const lines = await csv(t, cls.id, 'type=summary');
    assert.match(lines[0], /ด่าน 1 ครั้งแรก,ด่าน 1 ดีที่สุด,ด่าน 1 ล่าสุด,ด่าน 1 จำนวนครั้ง,ด่าน 2 ครั้งแรก/);
    assert.match(lines[1], /,s@test\.ac\.th,50,100,100,2,,,,0,/);
  });

  test('level and date filters, English headers', async () => {
    const { t, s, cls } = await classWithStudent();
    await send(s, 1);
    await send(s, 2);
    assert.equal((await csv(t, cls.id, 'type=attempts&level=2')).length, 2);
    assert.equal((await csv(t, cls.id, 'type=attempts&from=2000-01-01&to=2000-01-02')).length, 1);
    assert.match((await csv(t, cls.id, 'type=summary&level=1&lang=en'))[0], /^Student ID,First name,Last name,Email,Level 1 first,Level 1 best,Level 1 last,Level 1 attempts$/);
    await t.get(`/api/classes/${cls.id}/export.csv?type=nope`).expect(400);
  });

  test('text a spreadsheet could run as a formula is made harmless', async () => {
    const { t, cls } = await classWithStudent();
    const evil = await login(app, 'evil@test.ac.th');
    await evil.post('/api/me/role').send({ role: 'student' });
    await evil.patch('/api/me/profile').send({ firstName: '=HYPERLINK("x")', lastName: '+1', studentId: '6899999999999' }).expect(200);
    await evil.post('/api/classes/join').send({ code: cls.code, password: 'net1234' }).expect(200);
    const lines = await csv(t, cls.id, 'type=summary');
    const row = lines.find((l) => l.includes('evil@test.ac.th'))!;
    assert.match(row, /,"'=HYPERLINK\(""x""\)",'\+1,/);
  });
});
