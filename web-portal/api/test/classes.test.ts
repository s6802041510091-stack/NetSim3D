import assert from 'node:assert/strict';
import { after, beforeEach, describe, test } from 'node:test';
import type { Pool } from '../src/db.ts';
import { closeDb, freshDb, makeApp, student, TEACHER2, teacher } from './helpers.ts';

let db: Pool;
let app: ReturnType<typeof makeApp>;

beforeEach(async () => {
  db = await freshDb();
  app = makeApp(db);
});
after(closeDb);

async function createClass(t: Awaited<ReturnType<typeof teacher>>, name = 'ปวช.3/1', password = 'net1234') {
  const res = await t.post('/api/classes').send({ name, password }).expect(201);
  return res.body.class as { id: string; code: string; name: string };
}

describe('teacher manages classes', () => {
  test('create a class: gets a 6-character Class ID', async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    assert.match(cls.code, /^[A-HJ-NP-Z2-9]{6}$/);
    const list = (await t.get('/api/classes').expect(200)).body.classes;
    assert.equal(list.length, 1);
    assert.equal(list[0].memberCount, 0);
    assert.equal(list[0].open, true);
  });

  test('class password must be at least 4 characters', async () => {
    const t = await teacher(app);
    await t.post('/api/classes').send({ name: 'x', password: '123' }).expect(400);
  });

  test('students cannot create classes', async () => {
    const s = await student(app, 's@test.ac.th');
    assert.equal((await s.post('/api/classes').send({ name: 'x', password: '1234' }).expect(403)).body.error, 'teacher_only');
  });

  test('rename, change password, close', async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    const res = await t.patch(`/api/classes/${cls.id}`).send({ name: 'ปวช.3/2', open: false }).expect(200);
    assert.equal(res.body.class.name, 'ปวช.3/2');
    assert.equal(res.body.class.open, false);
    await t.patch(`/api/classes/${cls.id}`).send({}).expect(400);

    await t.patch(`/api/classes/${cls.id}`).send({ password: 'newpass', open: true }).expect(200);
    const s = await student(app, 's@test.ac.th');
    await s.post('/api/classes/join').send({ code: cls.code, password: 'net1234' }).expect(403);
    await s.post('/api/classes/join').send({ code: cls.code, password: 'newpass' }).expect(200);
  });

  test("another teacher cannot see or change someone else's class", async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    const other = await teacher(app, TEACHER2);
    await other.get(`/api/classes/${cls.id}`).expect(404);
    await other.patch(`/api/classes/${cls.id}`).send({ name: 'mine' }).expect(404);
    await other.delete(`/api/classes/${cls.id}`).expect(404);
    assert.equal((await other.get('/api/classes')).body.classes.length, 0);
  });

  test('a bad class id is a 400, not a server error', async () => {
    const t = await teacher(app);
    await t.get('/api/classes/not-a-uuid').expect(400);
  });

  test('members list shows name, student ID and email', async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    const s = await student(app, 's@test.ac.th');
    await s.post('/api/classes/join').send({ code: cls.code, password: 'net1234' }).expect(200);
    const res = await t.get(`/api/classes/${cls.id}`).expect(200);
    assert.equal(res.body.class.memberCount, 1);
    const m = res.body.members[0];
    assert.equal(m.firstName, 'สมชาย');
    assert.equal(m.lastName, 'ใจดี');
    assert.match(m.studentId, /^\d{13}$/);
    assert.equal(m.email, 's@test.ac.th');
  });

  test('remove a student from the class', async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    const s = await student(app, 's@test.ac.th');
    await s.post('/api/classes/join').send({ code: cls.code, password: 'net1234' });
    const sid = (await s.get('/api/me')).body.me.id;
    await t.delete(`/api/classes/${cls.id}/members/${sid}`).expect(200);
    assert.equal((await s.get('/api/classes')).body.classes.length, 0);
    assert.equal((await s.get('/api/me')).body.me.activeClass, null);
  });

  test('delete hides the class; restore brings it back with its students', async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    const s = await student(app, 's@test.ac.th');
    await s.post('/api/classes/join').send({ code: cls.code, password: 'net1234' });

    await t.delete(`/api/classes/${cls.id}`).expect(200);
    const tList = (await t.get('/api/classes')).body.classes;
    assert.ok(tList[0].deletedAt, 'teacher still sees it, marked deleted');
    assert.equal((await s.get('/api/classes')).body.classes.length, 0);
    assert.equal((await s.get('/api/me')).body.me.activeClass, null);
    await s.post('/api/classes/join').send({ code: cls.code, password: 'net1234' }).expect(404);
    await t.patch(`/api/classes/${cls.id}`).send({ name: 'x' }).expect(409);

    await t.post(`/api/classes/${cls.id}/restore`).expect(200);
    assert.equal((await s.get('/api/classes')).body.classes.length, 1);
  });
});

describe('students join classes', () => {
  test('join with Class ID + password; first class becomes the active one', async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    const s = await student(app, 's@test.ac.th');
    const res = await s.post('/api/classes/join').send({ code: cls.code.toLowerCase(), password: 'net1234' }).expect(200);
    assert.equal(res.body.alreadyMember, false);
    const me = (await s.get('/api/me')).body.me;
    assert.equal(me.activeClass.code, cls.code);
    const list = (await s.get('/api/classes')).body.classes;
    assert.equal(list[0].name, 'ปวช.3/1');
    assert.equal(list[0].teacherName, 'teacher');

    const again = await s.post('/api/classes/join').send({ code: cls.code, password: 'net1234' }).expect(200);
    assert.equal(again.body.alreadyMember, true);
  });

  test('a student can be in several classes and switch the active one', async () => {
    const t = await teacher(app);
    const a = await createClass(t, 'A');
    const b = await createClass(t, 'B');
    const s = await student(app, 's@test.ac.th');
    await s.post('/api/classes/join').send({ code: a.code, password: 'net1234' });
    await s.post('/api/classes/join').send({ code: b.code, password: 'net1234' });
    assert.equal((await s.get('/api/me')).body.me.activeClass.name, 'A');
    const res = await s.post('/api/me/active-class').send({ classId: b.id }).expect(200);
    assert.equal(res.body.me.activeClass.name, 'B');
  });

  test("cannot make a class active without being in it", async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    const s = await student(app, 's@test.ac.th');
    await s.post('/api/me/active-class').send({ classId: cls.id }).expect(404);
  });

  test('wrong code and wrong password are refused', async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    const s = await student(app, 's@test.ac.th');
    assert.equal((await s.post('/api/classes/join').send({ code: 'ZZZZZZ', password: 'net1234' }).expect(404)).body.error, 'class_not_found');
    assert.equal((await s.post('/api/classes/join').send({ code: cls.code, password: 'nope' }).expect(403)).body.error, 'wrong_password');
  });

  test('a closed class takes no new students but keeps its members', async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    const member = await student(app, 'm@test.ac.th');
    await member.post('/api/classes/join').send({ code: cls.code, password: 'net1234' }).expect(200);
    await t.patch(`/api/classes/${cls.id}`).send({ open: false });
    const s = await student(app, 's@test.ac.th');
    assert.equal((await s.post('/api/classes/join').send({ code: cls.code, password: 'net1234' }).expect(403)).body.error, 'class_closed');
    assert.equal((await member.get('/api/classes')).body.classes.length, 1);
  });

  test('5 wrong tries lock joining for a while, even with the right password', async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    const s = await student(app, 's@test.ac.th');
    for (let i = 0; i < 5; i++) await s.post('/api/classes/join').send({ code: cls.code, password: 'wrong' }).expect(403);
    const res = await s.post('/api/classes/join').send({ code: cls.code, password: 'net1234' }).expect(429);
    assert.equal(res.body.error, 'too_many_attempts');
    assert.ok(res.body.details.retryAfterSec > 0);
  });

  test('teachers cannot join classes', async () => {
    const t = await teacher(app);
    const cls = await createClass(t);
    await t.post('/api/classes/join').send({ code: cls.code, password: 'net1234' }).expect(403);
  });
});
