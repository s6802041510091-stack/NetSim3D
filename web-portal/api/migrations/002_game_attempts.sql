-- Phase 4: every finished game level, as the game scored it (GameProgress.record_attempt).

CREATE TABLE game_attempts (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  class_id           uuid REFERENCES classes(id) ON DELETE SET NULL,  -- the student's active class when sent
  client_id          text NOT NULL,                                     -- made by the game; makes resends harmless
  level              int  NOT NULL CHECK (level BETWEEN 1 AND 6),
  total              int  NOT NULL CHECK (total BETWEEN 0 AND 100),
  correctness        int  NOT NULL CHECK (correctness BETWEEN 0 AND 30),
  process            int  NOT NULL CHECK (process BETWEEN 0 AND 50),
  time_score         int  NOT NULL CHECK (time_score BETWEEN 0 AND 20),
  stars              int  NOT NULL CHECK (stars BETWEEN 0 AND 4),
  passed             boolean NOT NULL,
  elapsed_sec        real NOT NULL CHECK (elapsed_sec >= 0),
  decisions_correct  int  NOT NULL,
  decisions_total    int  NOT NULL,
  check_count        int,
  mistakes           jsonb NOT NULL DEFAULT '[]',   -- short lines shown on the summary
  step_times         jsonb NOT NULL DEFAULT '[]',   -- [{step, name, sec}]
  mistake_log        jsonb NOT NULL DEFAULT '[]',   -- [{text, what, why, step, step_name, at_sec, at_end}]
  result             jsonb NOT NULL,                -- everything the game sent, unchanged
  finished_at        timestamptz NOT NULL,          -- when the level ended (server clock)
  received_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_id, client_id)
);

CREATE INDEX game_attempts_student_idx ON game_attempts (student_id, level, finished_at);
CREATE INDEX game_attempts_class_idx ON game_attempts (class_id, level, finished_at);
