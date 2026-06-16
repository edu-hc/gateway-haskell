CREATE TABLE IF NOT EXISTS card_vault (
  token         TEXT        PRIMARY KEY,
  pan           TEXT        NOT NULL,
  pan_last_four CHAR(4)     NOT NULL,
  card_brand    TEXT        NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
