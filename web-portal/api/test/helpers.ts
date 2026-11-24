import pg from 'pg';
import request from 'supertest';
import { createApp } from '../src/app.ts';
import { createPool, migrate, syncAllowlist, type Pool } from '../src/db.ts';
import { JoinLimiter } from '../src/routes/classes.ts';

export const TEACHER = 'teacher@test.ac.th';
export const TEACHER2 = 'teacher2@test.ac.th';

let pool: Pool | undefined;

/** A pool on the test database (created on first use), with every table emptied. */
export async function freshDb(): Promise<Pool> {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('Set TEST_DATABASE_URL (see web-portal/README.md)');
  if (!pool) {
    const admin = new pg.Client({ connectionString: url.replace(/\/[^/?]+(\?|$)/, '/postgres$1') });
    await admin.connect();
    const dbName = new URL(url).pathname.slice(1);
    const exists = await admin.query('SELECT 1 FROM pg_database WHERE datname = $1', [dbName]);
    if (!exists.rowCount) await admin.query(`CREATE DATABASE "${dbName}"`);
    await admin.end();
    pool = createPool(url);
    await migrate(pool);
  }
  await pool.query('TRUNCATE users, teacher_allowlist, sessions, classes, enrollments CASCADE');
  await syncAllowlist(pool, [TEACHER, TEACHER2]);
  return pool;
}

export async function closeDb(): Promise<void> {
  await pool?.end();
  pool = undefined;
}

export function makeApp(db: Pool, { devLogin = true } = {}) {
  return createApp({ pool: db, devLogin, cookieSecure: false }, new JoinLimiter());
}

type App = ReturnType<typeof makeApp>;

/** A logged-in browser (keeps its cookie). */
export async function login(app: App, email: string, name?: string) {
  const agent = request.agent(app);
  const res = await agent.post('/api/auth/dev-login').send({ email, name });
  if (res.status !== 200) throw new Error(`login failed: ${res.status} ${JSON.stringify(res.body)}`);
  return agent;
}

let nextStudentId = 6800000000001;

/** A logged-in student with a complete profile. */
export async function student(app: App, email: string) {
  const agent = await login(app, email);
  await agent.post('/api/me/role').send({ role: 'student' }).expect(200);
  await agent.patch('/api/me/profile').send({ firstName: 'สมชาย', lastName: 'ใจดี', studentId: String(nextStudentId++) }).expect(200);
  return agent;
}

export async function teacher(app: App, email = TEACHER) {
  const agent = await login(app, email);
  await agent.post('/api/me/role').send({ role: 'teacher' }).expect(200);
  return agent;
}
