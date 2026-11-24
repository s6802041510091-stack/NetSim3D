-- Round 1: users, teacher allowlist, sessions, classes, enrollments.

CREATE TABLE users (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email            text NOT NULL UNIQUE,            -- lowercase, from Google (or the dev login)
  google_sub       text UNIQUE,                     -- Google account id, set once real Google login exists
  display_name     text NOT NULL DEFAULT '',        -- name from the Google account
  role             text CHECK (role IN ('teacher', 'student')),
  first_name       text,                            -- students fill these in themselves
  last_name        text,
  student_id       text UNIQUE CHECK (student_id ~ '^[0-9]{13}$'),
  active_class_id  uuid,                            -- the class the student/teacher is working in now
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- Emails allowed to take the teacher role (filled from TEACHER_EMAILS at startup).
CREATE TABLE teacher_allowlist (
  email     text PRIMARY KEY,
  added_at  timestamptz NOT NULL DEFAULT now()
);

-- Login sessions. Only a SHA-256 hash of the cookie value is stored.
CREATE TABLE sessions (
  token_hash  text PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL
);
CREATE INDEX sessions_user_idx ON sessions (user_id);

CREATE TABLE classes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                text NOT NULL UNIQUE,           -- Class ID given to students
  name                text NOT NULL,
  join_password_hash  text NOT NULL,                  -- bcrypt
  teacher_id          uuid NOT NULL REFERENCES users(id),
  open                boolean NOT NULL DEFAULT true,  -- accepts new students
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz                     -- hidden, can be restored
);
CREATE INDEX classes_teacher_idx ON classes (teacher_id);

CREATE TABLE enrollments (
  class_id    uuid NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  student_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (class_id, student_id)
);
CREATE INDEX enrollments_student_idx ON enrollments (student_id);

ALTER TABLE users
  ADD CONSTRAINT users_active_class_fk
  FOREIGN KEY (active_class_id) REFERENCES classes(id) ON DELETE SET NULL;
