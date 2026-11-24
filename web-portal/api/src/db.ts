import { readdir, readFile } from 'node:fs/promises';
import pg from 'pg';

export type Pool = pg.Pool;

export function createPool(connectionString: string): Pool {
  if (!connectionString) throw new Error('DATABASE_URL is not set');
  return new pg.Pool({ connectionString, max: 10 });
}

const MIGRATIONS_DIR = new URL('../migrations/', import.meta.url);

/** Applies every migrations/*.sql file not applied yet, in name order, one transaction each. */
export async function migrate(pool: Pool): Promise<string[]> {
  const client = await pool.connect();
  const applied: string[] = [];
  try {
    await client.query('SELECT pg_advisory_lock(424242)');
    await client.query(
      'CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())',
    );
    const done = new Set((await client.query<{ name: string }>('SELECT name FROM schema_migrations')).rows.map((r) => r.name));
    const files = (await readdir(MIGRATIONS_DIR)).filter((f) => f.endsWith('.sql')).sort();
    for (const file of files) {
      if (done.has(file)) continue;
      const sql = await readFile(new URL(file, MIGRATIONS_DIR), 'utf8');
      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
        await client.query('COMMIT');
        applied.push(file);
      } catch (err) {
        await client.query('ROLLBACK');
        throw new Error(`Migration ${file} failed: ${(err as Error).message}`);
      }
    }
  } finally {
    await client.query('SELECT pg_advisory_unlock(424242)').catch(() => {});
    client.release();
  }
  return applied;
}

/** Makes the teacher allowlist match the given emails (TEACHER_EMAILS is the source of truth). */
export async function syncAllowlist(pool: Pool, emails: string[]): Promise<void> {
  const list = [...new Set(emails.map((e) => e.trim().toLowerCase()).filter(Boolean))];
  await pool.query('DELETE FROM teacher_allowlist WHERE NOT (email = ANY($1::text[]))', [list]);
  for (const email of list) {
    await pool.query('INSERT INTO teacher_allowlist (email) VALUES ($1) ON CONFLICT DO NOTHING', [email]);
  }
}
