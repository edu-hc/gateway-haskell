CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT          NOT NULL,
  document     TEXT          NOT NULL UNIQUE,
  balance      NUMERIC(12,2) NOT NULL DEFAULT 0,
  currency     CHAR(3)       NOT NULL,
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
