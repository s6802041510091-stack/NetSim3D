import { createApp } from './app.ts';
import { createPool, migrate, syncAllowlist } from './db.ts';

const port = Number(process.env.PORT) || 3000;
const devLogin = process.env.DEV_LOGIN === 'true';
const cookieSecure = process.env.COOKIE_SECURE === 'true';
const teacherEmails = (process.env.TEACHER_EMAILS ?? '').split(',');

const pool = createPool(process.env.DATABASE_URL ?? '');

const applied = await migrate(pool);
if (applied.length) console.log(`Database migrations applied: ${applied.join(', ')}`);
await syncAllowlist(pool, teacherEmails);
await pool.query('DELETE FROM sessions WHERE expires_at < now()');

const server = createApp({ pool, devLogin, cookieSecure }).listen(port, () => {
  console.log(`NetSim API listening on port ${port}`);
  if (devLogin) console.warn('DEV_LOGIN is on: anyone can log in as any email. Never use this on the real server.');
});

for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  process.on(signal, () => {
    server.close(() => pool.end().then(() => process.exit(0)));
  });
}
