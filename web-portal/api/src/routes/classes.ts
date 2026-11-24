import { randomInt } from 'node:crypto';
import { compare, hash } from 'bcryptjs';
import { Router } from 'express';
import { z } from 'zod';
import { currentUser, requireStudent, requireTeacher } from '../auth.ts';
import type { Pool } from '../db.ts';
import { HttpError, isUniqueViolation, parse } from '../errors.ts';
import type { AppOptions } from './me.ts';

// No 0/O or 1/I, so a Class ID read aloud or off the board is not mistyped.
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 6;
const BCRYPT_ROUNDS = 10;

// Join attempts: at most 5 wrong tries per student per 10 minutes.
const JOIN_MAX_FAILURES = 5;
const JOIN_WINDOW_MS = 10 * 60 * 1000;

const className = z.string().trim().min(1).max(100);
const classPassword = z.string().min(4).max(64);
const idParam = z.object({ id: z.uuid() });

function newCode(): string {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return code;
}

type ClassRow = { id: string; code: string; name: string; open: boolean; createdAt: Date; deletedAt: Date | null };

const CLASS_COLUMNS = `c.id, c.code, c.name, c.open, c.created_at AS "createdAt", c.deleted_at AS "deletedAt"`;

export class JoinLimiter {
  private failures = new Map<string, { count: number; resetAt: number }>();

  check(userId: string, now = Date.now()): void {
    const f = this.failures.get(userId);
    if (f && f.resetAt > now && f.count >= JOIN_MAX_FAILURES) {
      throw new HttpError(429, 'too_many_attempts', { retryAfterSec: Math.ceil((f.resetAt - now) / 1000) });
    }
  }

  fail(userId: string, now = Date.now()): void {
    const f = this.failures.get(userId);
    if (!f || f.resetAt <= now) this.failures.set(userId, { count: 1, resetAt: now + JOIN_WINDOW_MS });
    else f.count++;
  }

  reset(userId: string): void {
    this.failures.delete(userId);
  }
}

export function classRoutes({ pool }: AppOptions, limiter = new JoinLimiter()): Router {
  const r = Router();

  /** The teacher's own class (deleted ones included), or 404 for anyone else's. */
  async function ownClass(teacherId: string, classId: string): Promise<ClassRow> {
    const { rows } = await pool.query<ClassRow>(
      `SELECT ${CLASS_COLUMNS} FROM classes c WHERE c.id = $1 AND c.teacher_id = $2`,
      [classId, teacherId],
    );
    if (!rows[0]) throw new HttpError(404, 'class_not_found');
    return rows[0];
  }

  // Teachers: their classes with member counts (deleted ones too, marked by deletedAt).
  // Students: the classes they joined.
  r.get('/classes', async (req, res) => {
    const user = currentUser(req);
    if (user.role === 'teacher') {
      await requireTeacher(pool, req);
      const { rows } = await pool.query(
        `SELECT ${CLASS_COLUMNS}, count(e.student_id)::int AS "memberCount"
         FROM classes c LEFT JOIN enrollments e ON e.class_id = c.id
         WHERE c.teacher_id = $1 GROUP BY c.id ORDER BY c.created_at DESC`,
        [user.id],
      );
      res.json({ classes: rows });
      return;
    }
    requireStudent(req, { profile: false });
    const { rows } = await pool.query(
      `SELECT c.id, c.code, c.name, e.joined_at AS "joinedAt", t.display_name AS "teacherName"
       FROM enrollments e JOIN classes c ON c.id = e.class_id JOIN users t ON t.id = c.teacher_id
       WHERE e.student_id = $1 AND c.deleted_at IS NULL ORDER BY e.joined_at DESC`,
      [user.id],
    );
    res.json({ classes: rows });
  });

  r.post('/classes', async (req, res) => {
    const teacher = await requireTeacher(pool, req);
    const body = parse(z.object({ name: className, password: classPassword }), req.body);
    const passwordHash = await hash(body.password, BCRYPT_ROUNDS);
    for (let attempt = 0; attempt < 10; attempt++) {
      try {
        const { rows } = await pool.query<ClassRow>(
          `INSERT INTO classes (code, name, join_password_hash, teacher_id) VALUES ($1, $2, $3, $4)
           RETURNING id, code, name, open, created_at AS "createdAt", deleted_at AS "deletedAt"`,
          [newCode(), body.name, passwordHash, teacher.id],
        );
        res.status(201).json({ class: { ...rows[0], memberCount: 0 } });
        return;
      } catch (err) {
        if (!isUniqueViolation(err, 'classes_code_key')) throw err;
      }
    }
    throw new HttpError(500, 'could_not_create_code');
  });

  r.get('/classes/:id', async (req, res) => {
    const teacher = await requireTeacher(pool, req);
    const { id } = parse(idParam, req.params);
    const cls = await ownClass(teacher.id, id);
    const { rows: members } = await pool.query(
      `SELECT u.id, u.first_name AS "firstName", u.last_name AS "lastName", u.student_id AS "studentId",
              u.email, e.joined_at AS "joinedAt"
       FROM enrollments e JOIN users u ON u.id = e.student_id
       WHERE e.class_id = $1 ORDER BY u.student_id NULLS LAST, u.email`,
      [id],
    );
    res.json({ class: { ...cls, memberCount: members.length }, members });
  });

  r.patch('/classes/:id', async (req, res) => {
    const teacher = await requireTeacher(pool, req);
    const { id } = parse(idParam, req.params);
    const body = parse(
      z.object({ name: className.optional(), password: classPassword.optional(), open: z.boolean().optional() })
        .refine((b) => b.name !== undefined || b.password !== undefined || b.open !== undefined, 'nothing to change'),
      req.body,
    );
    const cls = await ownClass(teacher.id, id);
    if (cls.deletedAt) throw new HttpError(409, 'class_deleted');
    const passwordHash = body.password === undefined ? null : await hash(body.password, BCRYPT_ROUNDS);
    await pool.query(
      `UPDATE classes SET name = COALESCE($2, name), join_password_hash = COALESCE($3, join_password_hash),
              open = COALESCE($4, open), updated_at = now()
       WHERE id = $1`,
      [id, body.name ?? null, passwordHash, body.open ?? null],
    );
    res.json({ class: await ownClass(teacher.id, id) });
  });

  // Hides the class (scores are kept); it can be restored.
  r.delete('/classes/:id', async (req, res) => {
    const teacher = await requireTeacher(pool, req);
    const { id } = parse(idParam, req.params);
    await ownClass(teacher.id, id);
    await pool.query('UPDATE classes SET deleted_at = now(), updated_at = now() WHERE id = $1 AND deleted_at IS NULL', [id]);
    await pool.query('UPDATE users SET active_class_id = NULL WHERE active_class_id = $1', [id]);
    res.json({ ok: true });
  });

  r.post('/classes/:id/restore', async (req, res) => {
    const teacher = await requireTeacher(pool, req);
    const { id } = parse(idParam, req.params);
    await ownClass(teacher.id, id);
    await pool.query('UPDATE classes SET deleted_at = NULL, updated_at = now() WHERE id = $1', [id]);
    res.json({ class: await ownClass(teacher.id, id) });
  });

  r.delete('/classes/:id/members/:studentId', async (req, res) => {
    const teacher = await requireTeacher(pool, req);
    const { id, studentId } = parse(z.object({ id: z.uuid(), studentId: z.uuid() }), req.params);
    await ownClass(teacher.id, id);
    await pool.query('DELETE FROM enrollments WHERE class_id = $1 AND student_id = $2', [id, studentId]);
    await pool.query('UPDATE users SET active_class_id = NULL WHERE id = $1 AND active_class_id = $2', [studentId, id]);
    res.json({ ok: true });
  });

  r.post('/classes/join', async (req, res) => {
    const student = requireStudent(req);
    const body = parse(z.object({ code: z.string().trim().min(1).max(20), password: z.string().min(1).max(64) }), req.body);
    limiter.check(student.id);
    const { rows } = await pool.query<{ id: string; code: string; name: string; open: boolean; join_password_hash: string }>(
      'SELECT id, code, name, open, join_password_hash FROM classes WHERE code = $1 AND deleted_at IS NULL',
      [body.code.toUpperCase()],
    );
    const cls = rows[0];
    if (!cls) {
      limiter.fail(student.id);
      throw new HttpError(404, 'class_not_found');
    }
    if (!(await compare(body.password, cls.join_password_hash))) {
      limiter.fail(student.id);
      throw new HttpError(403, 'wrong_password');
    }
    limiter.reset(student.id);
    const already = await pool.query('SELECT 1 FROM enrollments WHERE class_id = $1 AND student_id = $2', [cls.id, student.id]);
    if (!already.rowCount) {
      // A closed class keeps its members but takes no new ones.
      if (!cls.open) throw new HttpError(403, 'class_closed');
      await pool.query('INSERT INTO enrollments (class_id, student_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [cls.id, student.id]);
    }
    await pool.query('UPDATE users SET active_class_id = COALESCE(active_class_id, $1) WHERE id = $2', [cls.id, student.id]);
    res.json({ class: { id: cls.id, code: cls.code, name: cls.name }, alreadyMember: Boolean(already.rowCount) });
  });

  return r;
}
