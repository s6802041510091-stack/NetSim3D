// Calls to the NetSim API (same site, so the login cookie goes along by itself).

export class ApiError extends Error {
  status: number;
  code: string;
  details?: unknown;

  constructor(status: number, code: string, details?: unknown) {
    super(code);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

async function call<T>(method: string, path: string, body?: unknown): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`/api${path}`, {
      method,
      credentials: 'same-origin',
      headers: body === undefined ? {} : { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(0, 'network');
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new ApiError(res.status, data.error ?? 'generic', data.details);
  return data as T;
}

export type Role = 'teacher' | 'student';

export type Me = {
  id: string;
  email: string;
  displayName: string;
  role: Role | null;
  firstName: string | null;
  lastName: string | null;
  studentId: string | null;
  activeClass: { id: string; code: string; name: string } | null;
  canTeach: boolean;
  needsRole: boolean;
  needsProfile: boolean;
};

export type Config = { devLogin: boolean; googleLogin: boolean };

export type TeacherClass = {
  id: string;
  code: string;
  name: string;
  open: boolean;
  createdAt: string;
  deletedAt: string | null;
  memberCount: number;
};

export type StudentClass = { id: string; code: string; name: string; joinedAt: string; teacherName: string };

export type Member = {
  id: string;
  firstName: string | null;
  lastName: string | null;
  studentId: string | null;
  email: string;
  joinedAt: string;
};

export type Brief = { total: number; stars: number; passed: boolean; finishedAt: string };
export type LevelSummary = { attempts: number; first: Brief; best: Brief; last: Brief };
export type StudentResults = {
  id: string;
  studentId: string | null;
  firstName: string | null;
  lastName: string | null;
  email: string;
  former: boolean;
  levels: Record<string, LevelSummary>;
};
export type GameResults = { levels: number[]; passScore: number; students: StudentResults[] };

export type GameAttempt = {
  id: string;
  level: number;
  attemptNo: number;
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
  mistakeLog: { what?: string; why?: string; text?: string; step?: number; at_sec?: number; at_end?: boolean }[];
  finishedAt: string;
};

export type CsvType = 'summary' | 'attempts' | 'steps';

export function csvUrl(classId: string, q: { type: CsvType; level?: number; from?: string; to?: string; lang: string }): string {
  const p = new URLSearchParams({ type: q.type, lang: q.lang });
  if (q.level) p.set('level', String(q.level));
  if (q.from) p.set('from', q.from);
  if (q.to) p.set('to', q.to);
  return `/api/classes/${classId}/export.csv?${p}`;
}

type MeResponse = { me: Me };

export const api = {
  config: () => call<Config>('GET', '/config'),
  me: () => call<{ me: Me | null }>('GET', '/me'),
  devLogin: (email: string, name?: string) => call<MeResponse>('POST', '/auth/dev-login', { email, name: name || undefined }),
  logout: () => call<{ ok: true }>('POST', '/auth/logout'),
  setRole: (role: Role) => call<MeResponse>('POST', '/me/role', { role }),
  saveProfile: (p: { firstName: string; lastName: string; studentId: string }) => call<MeResponse>('PATCH', '/me/profile', p),
  setActiveClass: (classId: string | null) => call<MeResponse>('POST', '/me/active-class', { classId }),

  teacherClasses: () => call<{ classes: TeacherClass[] }>('GET', '/classes'),
  studentClasses: () => call<{ classes: StudentClass[] }>('GET', '/classes'),
  createClass: (name: string, password: string) => call<{ class: TeacherClass }>('POST', '/classes', { name, password }),
  classDetail: (id: string) => call<{ class: TeacherClass; members: Member[] }>('GET', `/classes/${id}`),
  updateClass: (id: string, changes: { name?: string; password?: string; open?: boolean }) =>
    call<{ class: TeacherClass }>('PATCH', `/classes/${id}`, changes),
  deleteClass: (id: string) => call<{ ok: true }>('DELETE', `/classes/${id}`),
  restoreClass: (id: string) => call<{ class: TeacherClass }>('POST', `/classes/${id}/restore`),
  removeMember: (id: string, studentId: string) => call<{ ok: true }>('DELETE', `/classes/${id}/members/${studentId}`),
  gameResults: (id: string) => call<GameResults>('GET', `/classes/${id}/game-results`),
  gameAttempts: (id: string, studentId: string) =>
    call<{ attempts: GameAttempt[] }>('GET', `/classes/${id}/game-attempts?studentId=${encodeURIComponent(studentId)}`),
  joinClass: (code: string, password: string) =>
    call<{ class: { id: string; code: string; name: string }; alreadyMember: boolean }>('POST', '/classes/join', { code, password }),
};
