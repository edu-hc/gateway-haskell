CREATE TABLE IF NOT EXISTS transactions (
  id             UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id      UUID          NOT NULL REFERENCES users(id),
  receiver_id    UUID          NOT NULL REFERENCES users(id),
  amount         NUMERIC(12,2) NOT NULL,
  currency_code  CHAR(3)       NOT NULL,
  installments   SMALLINT      NOT NULL DEFAULT 1,
  pan_last_four  CHAR(4)       NOT NULL,
  card_brand     TEXT          NOT NULL,
  billing_email  TEXT          NOT NULL,
  ip_address     INET          NOT NULL,
  response_code  CHAR(2),
  status         TEXT          NOT NULL DEFAULT 'PENDING',
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_sender_id   ON transactions(sender_id);
CREATE INDEX IF NOT EXISTS idx_transactions_receiver_id ON transactions(receiver_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status      ON transactions(status);
