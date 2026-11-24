import assert from 'node:assert/strict';
import { after, beforeEach, describe, test } from 'node:test';
import request from 'supertest';
import type { Pool } from '../src/db.ts';
import { syncAllowlist } from '../src/db.ts';
import { closeDb, freshDb, login, makeApp, student, TEACHER, teacher } from './helpers.ts';

let db: Pool;
let app: ReturnType<typeof makeApp>;

beforeEach(async () => {
  db = await freshDb();
  app = makeApp(db);
});
after(closeDb);

describe('config and login', () => {
  test('config says the dev login is on', async () => {
    const res = await request(app).get('/api/config').expect(200);
    assert.deepEqual(res.body, { devLogin: true, googleLogin: false });
  });

  test('dev login does not exist when turned off', async () => {
    const off = makeApp(db, { devLogin: false });
    await request(off).post('/api/auth/dev-login').send({ email: 'a@test.ac.th' }).expect(404);
  });

  test('logged out: me is null', async () => {
    const res = await request(app).get('/api/me').expect(200);
    assert.equal(res.body.me, null);
  });

  test('dev login rejects a bad email', async () => {
    const res = await request(app).post('/api/auth/dev-login').send({ email: 'not-an-email' }).expect(400);
    assert.equal(res.body.error, 'invalid_input');
  });

  test('login sets an HttpOnly cookie and the new user must pick a role', async () => {
    const res = await request(app).post('/api/auth/dev-login').send({ email: 'New@Test.ac.th' }).expect(200);
    const cookie = String(res.headers['set-cookie']);
    assert.match(cookie, /netsim_session=/);
    assert.match(cookie, /HttpOnly/);
    assert.match(cookie, /SameSite=Lax/);
    assert.equal(res.body.me.email, 'new@test.ac.th');
    assert.equal(res.body.me.needsRole, true);
    assert.equal(res.body.me.canTeach, false);
  });

  test('logout ends the session', async () => {
    const agent = await login(app, 'a@test.ac.th');
    assert.notEqual((await agent.get('/api/me')).body.me, null);
    await agent.post('/api/auth/logout').expect(200);
    assert.equal((await agent.get('/api/me')).body.me, null);
  });

  test('a cookie from another site cannot change data', async () => {
    const agent = await login(app, 'a@test.ac.th');
    const res = await agent.post('/api/me/role').set('Origin', 'https://evil.example').send({ role: 'student' }).expect(403);
    assert.equal(res.body.error, 'bad_origin');
  });
});

describe('roles', () => {
  test('anyone can be a student; then a profile is needed', async () => {
    const agent = await login(app, 'a@test.ac.th');
    const res = await agent.post('/api/me/role').send({ role: 'student' }).expect(200);
    assert.equal(res.body.me.role, 'student');
    assert.equal(res.body.me.needsProfile, true);
  });

  test('only allowlisted emails can be teachers', async () => {
    const agent = await login(app, 'a@test.ac.th');
    assert.equal((await agent.post('/api/me/role').send({ role: 'teacher' }).expect(403)).body.error, 'not_allowed_teacher');
    const t = await login(app, TEACHER);
    const res = await t.post('/api/me/role').send({ role: 'teacher' }).expect(200);
    assert.equal(res.body.me.role, 'teacher');
    assert.equal(res.body.me.needsProfile, false);
  });

  test('the role cannot be changed once chosen', async () => {
    const agent = await login(app, TEACHER);
    await agent.post('/api/me/role').send({ role: 'student' }).expect(200);
    assert.equal((await agent.post('/api/me/role').send({ role: 'teacher' }).expect(409)).body.error, 'role_already_set');
  });

  test('a teacher taken off the allowlist loses teacher access', async () => {
    const t = await teacher(app);
    await t.get('/api/classes').expect(200);
    await syncAllowlist(db, []);
    assert.equal((await t.get('/api/classes').expect(403)).body.error, 'teacher_only');
  });
});

describe('student profile', () => {
  test('needs first name, last name and a 13-digit student ID', async () => {
    const agent = await login(app, 'a@test.ac.th');
    await agent.post('/api/me/role').send({ role: 'student' });
    for (const studentId of ['123', '68000000000001', '68000000000ab', '']) {
      await agent.patch('/api/me/profile').send({ firstName: 'ก', lastName: 'ข', studentId }).expect(400);
    }
    await agent.patch('/api/me/profile').send({ firstName: ' ', lastName: 'ข', studentId: '6800000000000' }).expect(400);
    const res = await agent.patch('/api/me/profile')
      .send({ firstName: ' สมหญิง ', lastName: 'รักเรียน', studentId: '6800000000000' }).expect(200);
    assert.equal(res.body.me.firstName, 'สมหญิง');
    assert.equal(res.body.me.studentId, '6800000000000');
    assert.equal(res.body.me.needsProfile, false);
  });

  test('two students cannot share a student ID', async () => {
    const a = await login(app, 'a@test.ac.th');
    await a.post('/api/me/role').send({ role: 'student' });
    await a.patch('/api/me/profile').send({ firstName: 'ก', lastName: 'ข', studentId: '6800000000000' }).expect(200);
    const b = await login(app, 'b@test.ac.th');
    await b.post('/api/me/role').send({ role: 'student' });
    const res = await b.patch('/api/me/profile').send({ firstName: 'ค', lastName: 'ง', studentId: '6800000000000' }).expect(409);
    assert.equal(res.body.error, 'student_id_taken');
  });

  test('teachers do not have a student profile', async () => {
    const t = await teacher(app);
    await t.patch('/api/me/profile').send({ firstName: 'ก', lastName: 'ข', studentId: '6800000000000' }).expect(403);
  });

  test('students without a profile cannot join classes', async () => {
    const agent = await login(app, 'a@test.ac.th');
    await agent.post('/api/me/role').send({ role: 'student' });
    const res = await agent.post('/api/classes/join').send({ code: 'ABCDEF', password: 'x' }).expect(403);
    assert.equal(res.body.error, 'profile_required');
  });

  test('student helper gives a complete profile', async () => {
    const s = await student(app, 's@test.ac.th');
    assert.equal((await s.get('/api/me')).body.me.needsProfile, false);
  });
});
