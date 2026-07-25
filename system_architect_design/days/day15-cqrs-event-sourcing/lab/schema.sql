-- Day 15 — event store + read model.

-- The event store: append-only source of truth.
CREATE TABLE IF NOT EXISTS events (
  global_seq   BIGSERIAL   PRIMARY KEY,           -- global order, for projectors
  aggregate_id TEXT        NOT NULL,
  seq          INT         NOT NULL,              -- per-aggregate version
  event_type   TEXT        NOT NULL,
  payload      JSONB       NOT NULL,
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (aggregate_id, seq)                      -- optimistic concurrency lock-free
);

-- Enforce "append-only" for real: UPDATE/DELETE raise. (TRUNCATE of the VIEW is
-- fine; we never truncate events.) Try `UPDATE events SET ...` to feel it bite.
CREATE OR REPLACE FUNCTION forbid_event_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'events is append-only: append a correcting event, do not mutate history';
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS events_append_only ON events;
CREATE TRIGGER events_append_only
  BEFORE UPDATE OR DELETE ON events
  FOR EACH ROW EXECUTE FUNCTION forbid_event_mutation();

-- A read model (projection): denormalized for the "order status" query. Disposable
-- and rebuildable — TRUNCATE + replay reconstructs it from the events alone.
CREATE TABLE IF NOT EXISTS order_status_view (
  order_id    TEXT   PRIMARY KEY,
  status      TEXT   NOT NULL,
  total_cents BIGINT NOT NULL DEFAULT 0,
  last_seq    INT    NOT NULL DEFAULT 0
);

-- The projector's resumable position in the global log.
CREATE TABLE IF NOT EXISTS projector_checkpoint (
  id       INT    PRIMARY KEY DEFAULT 1,
  position BIGINT NOT NULL DEFAULT 0
);
INSERT INTO projector_checkpoint (id, position) VALUES (1, 0)
  ON CONFLICT (id) DO NOTHING;
