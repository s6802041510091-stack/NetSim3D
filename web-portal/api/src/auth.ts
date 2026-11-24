import { createHash, randomBytes } from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';
import type { Pool } from './db.ts';
import { HttpError } from './errors.ts';

export const SESSION_COOKIE = 'netsim_session';
const SESSION_DAYS = 14;

export type Role = 'teacher' | 'student';

export type User = {
  id: string;
  email: string;
  displayName: string;
  role: Role | null;
  firstName: string | null;
  lastName: string | null;
  studentId: string | null;
  activeClassId: string | null;
};

declare global {
  namespace Express {
    interface Request {
      user?: User;
    }
  }
}

const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');

function cookie(value: string, maxAge: number, secure: boolean): string {
  return `${SESSION_COOKIE}=${value}; HttpOnly; SameSite=Lax; Path=/; Max-Age=${maxAge}${secure ? '; Secure' : ''}`;
}

function readToken(req: Request): string | null {
  for (const part of (req.headers.cookie ?? '').split(';')) {
    const i = part.indexOf('=');
    if (i > 0 && part.slice(0, i).trim() === SESSION_COOKIE) return part.slice(i + 1).trim() || null;
  }
  return null;
}

export async function startSession(pool: Pool, res: Response, userId: string, secure: boolean): Promise<void> {
  const token = randomBytes(32).toString('base64url');
  await pool.query(
    `INSERT INTO sessions (token_hash, user_id, expires_at) VALUES ($1, $2, now() + make_interval(days => $3))`,
    [hashToken(token), userId, SESSION_DAYS],
  );
  res.setHeader('Set-Cookie', cookie(token, SESSION_DAYS * 86400, secure));
}

export async function endSession(pool: Pool, req: Request, res: Response, secure: boolean): Promise<void> {
  const token = readToken(req);
  if (token) await pool.query('DELETE FROM sessions WHERE token_hash = $1', [hashToken(token)]);
  res.setHeader('Set-Cookie', cookie('', 0, secure));
}

export const USER_COLUMNS = `u.id, u.email, u.display_name AS "displayName", u.role,
  u.first_name AS "firstName", u.last_name AS "lastName", u.student_id AS "studentId",
  u.active_class_id AS "activeClassId"`;

export async function findUser(pool: Pool, id: string): Promise<User> {
  const { rows } = await pool.query<User>(`SELECT ${USER_COLUMNS} FROM users u WHERE u.id = $1`, [id]);
  if (!rows[0]) throw new HttpError(401, 'not_logged_in');
  return rows[0];
}

/** Puts the logged-in user (if any) on req.user. */
export function loadUser(pool: Pool) {
  return async (req: Request, _res: Response, next: NextFunction) => {
    const token = readToken(req);
    if (token) {
      const { rows } = await pool.query<User>(
        `SELECT ${USER_COLUMNS} FROM sessions s JOIN users u ON u.id = s.user_id
         WHERE s.token_hash = $1 AND s.expires_at > now()`,
        [hashToken(token)],
      );
      req.user = rows[0];
    }
    next();
  };
}

export function currentUser(req: Request): User {
  if (!req.user) throw new HttpError(401, 'not_logged_in');
  return req.user;
}

export async function isAllowedTeacher(pool: Pool, email: string): Promise<boolean> {
  const { rowCount } = await pool.query('SELECT 1 FROM teacher_allowlist WHERE email = $1', [email]);
  return (rowCount ?? 0) > 0;
}

/** A teacher whose email is still on the allowlist. Removing the email takes teacher access away. */
export async function requireTeacher(pool: Pool, req: Request): Promise<User> {
  const user = currentUser(req);
  if (user.role !== 'teacher' || !(await isAllowedTeacher(pool, user.email))) throw new HttpError(403, 'teacher_only');
  return user;
}

export function profileComplete(user: User): boolean {
  return Boolean(user.firstName && user.lastName && user.studentId);
}

/** A student who has filled in first name, last name and student ID. */
export function requireStudent(req: Request, { profile = true } = {}): User {
  const user = currentUser(req);
  if (user.role !== 'student') throw new HttpError(403, 'student_only');
  if (profile && !profileComplete(user)) throw new HttpError(403, 'profile_required');
  return user;
}
