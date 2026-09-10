-- OktaPonto SQLite schema contract — version 1
-- Frozen on 2026-09-09. This is the human-reviewable migration baseline that
-- must remain immutable once a later schema version is introduced.
PRAGMA foreign_keys = ON;

CREATE TABLE work_days (
  local_date TEXT NOT NULL PRIMARY KEY,
  include_in_timesheet INTEGER NOT NULL DEFAULT 1 CHECK (include_in_timesheet IN (0, 1)),
  activity TEXT,
  note TEXT,
  created_at_utc_ms INTEGER NOT NULL,
  updated_at_utc_ms INTEGER NOT NULL
);

CREATE TABLE punches (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  local_date TEXT NOT NULL REFERENCES work_days(local_date),
  occurred_at_utc_ms INTEGER NOT NULL,
  utc_offset_min INTEGER NOT NULL,
  kind TEXT NOT NULL,
  is_edited INTEGER NOT NULL DEFAULT 0 CHECK (is_edited IN (0, 1)),
  deleted_at_utc_ms INTEGER,
  created_at_utc_ms INTEGER NOT NULL,
  updated_at_utc_ms INTEGER NOT NULL
);

CREATE TABLE punch_audit (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  punch_id INTEGER NOT NULL REFERENCES punches(id),
  action TEXT NOT NULL,
  before_json TEXT,
  after_json TEXT,
  changed_at_utc_ms INTEGER NOT NULL
);

CREATE TABLE profile_settings (
  id INTEGER NOT NULL PRIMARY KEY,
  employee_name TEXT NOT NULL,
  job_title TEXT NOT NULL,
  work_mode TEXT NOT NULL,
  default_activity TEXT NOT NULL,
  updated_at_utc_ms INTEGER NOT NULL
);

CREATE TABLE reminders (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  label TEXT NOT NULL,
  hour INTEGER NOT NULL,
  minute INTEGER NOT NULL,
  weekdays_mask INTEGER NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1))
);

CREATE INDEX idx_punches_local_date_time
ON punches(local_date, occurred_at_utc_ms);

CREATE INDEX idx_punch_audit_punch
ON punch_audit(punch_id, changed_at_utc_ms);

-- Additional fail-closed integrity guards are installed idempotently from
-- AppDatabase._ensureIntegrityGuards(). They are kept out of the table DDL so
-- Drift remains the authoritative table generator while this file records the
-- immutable v1 migration contract.
CREATE TRIGGER trg_punch_kind_insert
BEFORE INSERT ON punches WHEN NEW.kind NOT IN ('in','out')
BEGIN SELECT RAISE(ABORT, 'invalid punch kind'); END;

CREATE TRIGGER trg_punch_kind_update
BEFORE UPDATE OF kind ON punches WHEN NEW.kind NOT IN ('in','out')
BEGIN SELECT RAISE(ABORT, 'invalid punch kind'); END;

CREATE TRIGGER trg_reminder_bounds_insert
BEFORE INSERT ON reminders
WHEN NEW.hour < 0 OR NEW.hour > 23
  OR NEW.minute < 0 OR NEW.minute > 59
  OR NEW.weekdays_mask < 1 OR NEW.weekdays_mask > 127
BEGIN SELECT RAISE(ABORT, 'invalid reminder'); END;

CREATE TRIGGER trg_reminder_bounds_update
BEFORE UPDATE OF hour, minute, weekdays_mask ON reminders
WHEN NEW.hour < 0 OR NEW.hour > 23
  OR NEW.minute < 0 OR NEW.minute > 59
  OR NEW.weekdays_mask < 1 OR NEW.weekdays_mask > 127
BEGIN SELECT RAISE(ABORT, 'invalid reminder'); END;
