import { Router } from 'express';
import { z } from 'zod';
import {
  currentUser, endSession, findUser, isAllowedTeacher, profileComplete, startSession, type User,
} from '../auth.ts';
import type { Pool } from '../db.ts';
import { HttpError, isUniqueViolation, parse } from '../errors.ts';

export type AppOptions = { pool: Pool; devLogin: boolean; cookieSecure: boolean };

/** What the website (and later the game) needs to know about the logged-in user. */
export async function meView(pool: Pool, user: User) {
  const canTeach = await isAllowedTeacher(pool, user.email);
  let activeClass: { id: string; code: string; name: string } | null = null;
  if (user.activeClassId) {
    const { rows } = await pool.query(
      `SELECT c.id, c.code, c.name FROM classes c
       WHERE c.id = $1 AND c.deleted_at IS NULL
         AND (c.teacher_id = $2 OR EXISTS (SELECT 1 FROM enrollments e WHERE e.class_id = c.id AND e.student_id = $2))`,
      [user.activeClassId, user.id],
    );
    activeClass = rows[0] ?? null;
  }
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    role: user.role,
    firstName: user.firstName,
    lastName: user.lastName,
    studentId: user.studentId,
    activeClass,
    canTeach,
    needsRole: user.role === null,
    needsProfile: user.role === 'student' && !profileComplete(user),
  };
}

const nameField = z.string().trim().min(1).max(100);

export function authRoutes({ pool, devLogin, cookieSecure }: AppOptions): Router {
  const r = Router();

  r.get('/config', (_req, res) => {
    res.json({ devLogin, googleLogin: false });
  });

  // Test login for development: anyone can type any email. Never enable on the real server.
  r.post('/auth/dev-login', async (req, res) => {
    if (!devLogin) throw new HttpError(404, 'not_found');
    const body = parse(z.object({ email: z.email().max(200), name: z.string().trim().max(100).optional() }), req.body);
    const email = body.email.toLowerCase();
    const name = body.name || email.split('@')[0];
    const { rows } = await pool.query<{ id: string }>(
      `INSERT INTO users (email, display_name) VALUES ($1, $2)
       ON CONFLICT (email) DO UPDATE SET display_name = CASE WHEN $3 THEN EXCLUDED.display_name ELSE users.display_name END,
                                         updated_at = now()
       RETURNING id`,
      [email, name, Boolean(body.name)],
    );
    await startSession(pool, res, rows[0].id, cookieSecure);
    res.json({ me: await meView(pool, await findUser(pool, rows[0].id)) });
  });

  r.post('/auth/logout', async (req, res) => {
    await endSession(pool, req, res, cookieSecure);
    res.json({ ok: true });
  });

  r.get('/me', async (req, res) => {
    res.json({ me: req.user ? await meView(pool, req.user) : null });
  });

  // Chosen once, the first time a user logs in. Teachers must be on the allowlist.
  r.post('/me/role', async (req, res) => {
    const user = currentUser(req);
    const { role } = parse(z.object({ role: z.enum(['teacher', 'student']) }), req.body);
    if (user.role) throw new HttpError(409, 'role_already_set');
    if (role === 'teacher' && !(await isAllowedTeacher(pool, user.email))) throw new HttpError(403, 'not_allowed_teacher');
    await pool.query('UPDATE users SET role = $1, updated_at = now() WHERE id = $2', [role, user.id]);
    res.json({ me: await meView(pool, await findUser(pool, user.id)) });
  });

  r.patch('/me/profile', async (req, res) => {
    const user = currentUser(req);
    if (user.role !== 'student') throw new HttpError(403, 'student_only');
    const body = parse(
      z.object({
        firstName: nameField,
        lastName: nameField,
        studentId: z.string().trim().regex(/^\d{13}$/, 'student ID must be 13 digits'),
      }),
      req.body,
    );
    try {
      await pool.query(
        'UPDATE users SET first_name = $1, last_name = $2, student_id = $3, updated_at = now() WHERE id = $4',
        [body.firstName, body.lastName, body.studentId, user.id],
      );
    } catch (err) {
      if (isUniqueViolation(err, 'users_student_id_key')) throw new HttpError(409, 'student_id_taken');
      throw err;
    }
    res.json({ me: await meView(pool, await findUser(pool, user.id)) });
  });

  // The class the user is working in now (students: one they joined; teachers: one they own).
  r.post('/me/active-class', async (req, res) => {
    const user = currentUser(req);
    const { classId } = parse(z.object({ classId: z.uuid().nullable() }), req.body);
    if (classId) {
      const { rowCount } = await pool.query(
        `SELECT 1 FROM classes c WHERE c.id = $1 AND c.deleted_at IS NULL
           AND (c.teacher_id = $2 OR EXISTS (SELECT 1 FROM enrollments e WHERE e.class_id = c.id AND e.student_id = $2))`,
        [classId, user.id],
      );
      if (!rowCount) throw new HttpError(404, 'class_not_found');
    }
    await pool.query('UPDATE users SET active_class_id = $1, updated_at = now() WHERE id = $2', [classId, user.id]);
    res.json({ me: await meView(pool, await findUser(pool, user.id)) });
  });

  return r;
}
