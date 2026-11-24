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
  joinClass: (code: string, password: string) =>
    call<{ class: { id: string; code: string; name: string }; alreadyMember: boolean }>('POST', '/classes/join', { code, password }),
};
