# Haskell Payments Gateway

A payment gateway built in Haskell with Servant, PostgreSQL and Warp. Supports user management, balance transfers and card transaction processing with a mock authorizer.

**Live API:** `https://payment-gateway-oau7.onrender.com`

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Haskell (GHC 9.6.4) |
| Web framework | Servant 0.20 + Warp 3.3 |
| Database | PostgreSQL via `postgresql-simple` |
| Connection pool | `resource-pool` |
| Containerization | Docker (two-stage build) |
| Deploy | Render (free tier) |

---

## Architecture

```
Client → Servant Router → AppM (ReaderT AppEnv IO) → DB (postgresql-simple)
```

- `AppM = ReaderT AppEnv IO` — no ExceptT; errors are thrown via `throwIO`
- `AppEnv` holds the connection pool
- Migrations run automatically on startup via `entrypoint.sh`
- CORS is open (all origins) to allow frontend integration

---

## Database Schema

### users
| Column | Type | Notes |
|---|---|---|
| id | UUID | PK, auto-generated |
| name | TEXT | |
| document | TEXT | UNIQUE |
| balance | NUMERIC(12,2) | Default 0 |
| currency | CHAR(3) | e.g. `BRL`, `USD` |
| created_at | TIMESTAMPTZ | |

### transactions
| Column | Type | Notes |
|---|---|---|
| id | UUID | PK, auto-generated |
| sender_id | UUID | FK → users |
| receiver_id | UUID | FK → users |
| amount | NUMERIC(12,2) | |
| currency_code | CHAR(3) | |
| installments | SMALLINT | |
| pan_last_four | CHAR(4) | Last 4 digits of card |
| card_brand | TEXT | e.g. `VISA`, `MASTERCARD` |
| billing_email | TEXT | |
| ip_address | INET | |
| response_code | CHAR(2) | `00` = approved, `05` = generic decline, `51` = insufficient funds |
| status | TEXT | `PENDING`, `APPROVED`, `DECLINED`, `ERROR` |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

---

## Transaction Flow

```
POST /transactions
  │
  ├─ 404  sender not found
  ├─ 404  receiver not found
  ├─ 422  currency mismatch (sender.currency ≠ receiver.currency)
  │
  ├─ INSERT transaction (status = PENDING)
  │
  ├─ sender.balance < amount?
  │     └─ DECLINED (response_code = "51")
  │
  └─ call mock authorizer
        ├─ "00" → APPROVED
        │     ├─ debit sender balance
        │     └─ credit receiver balance
        ├─ "05" → DECLINED
        └─ "51" → DECLINED
```

The mock authorizer returns `"00"` (approved) ~80% of the time, `"05"` ~10%, and `"51"` ~10%.

---

## API Reference

Base URL: `https://payment-gateway-oau7.onrender.com`

### Health

```
GET /health
→ 200 "OK"
```

---

### Users

#### Create user
```
POST /users
Content-Type: application/json

{
  "name": "João Silva",
  "document": "12345678900",
  "balance": 1000.00,
  "currency": "BRL"
}

→ 201 User
→ 409 "Document already exists"
```

#### List users
```
GET /users
→ 200 [User]
```

#### Get user
```
GET /users/:id
→ 200 User
→ 404 "User not found"
```

#### Update user
```
PUT /users/:id
Content-Type: application/json

{
  "name": "João Atualizado",
  "document": "12345678900"
}

→ 200 User
→ 404 "User not found"
→ 409 "Document already exists"
```

#### Delete user
```
DELETE /users/:id
→ 204 No Content
→ 404 "User not found"
→ 409 "User has transactions"
```

---

### Transactions

#### Create transaction
```
POST /transactions
Content-Type: application/json

{
  "sender_id": "uuid-sender",
  "receiver_id": "uuid-receiver",
  "amount": 150.00,
  "installments": 1,
  "pan": "4111111111111111",
  "pan_last_four": "1111",
  "card_brand": "VISA",
  "billing_email": "joao@email.com",
  "ip_address": "192.168.0.1"
}

→ 201 Transaction
→ 404 "Sender not found"
→ 404 "Receiver not found"
→ 422 "Currency mismatch"
```

#### Get transaction
```
GET /transactions/:id
→ 200 Transaction
→ 404 "Transaction not found"
```

---

### Response Shapes

**User**
```json
{
  "id": "a1b2c3d4-...",
  "name": "João Silva",
  "document": "12345678900",
  "balance": 1000.00,
  "currency": "BRL",
  "created_at": "2024-01-01T00:00:00Z"
}
```

**Transaction**
```json
{
  "id": "e5f6g7h8-...",
  "sender_id": "uuid-sender",
  "receiver_id": "uuid-receiver",
  "amount": 150.00,
  "currency_code": "BRL",
  "installments": 1,
  "pan_last_four": "1111",
  "card_brand": "VISA",
  "billing_email": "joao@email.com",
  "ip_address": "192.168.0.1",
  "response_code": "00",
  "status": "APPROVED",
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

---

## Local Development

### Prerequisites

- GHC 9.6.4 + Cabal 3.10
- PostgreSQL (or Docker)
- `libpq-dev`

### 1. Start PostgreSQL

```bash
docker run -d \
  --name pg \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=gateway \
  -p 5432:5432 \
  postgres:16
```

### 2. Set environment variable

```bash
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/gateway"
```

### 3. Run migrations

```bash
for f in $(ls migrations/*.sql | sort); do
  psql "$DATABASE_URL" -f "$f"
done
```

### 4. Build and run

```bash
cabal build
cabal run gateway
```

Server starts on port `8080`.

---

## Docker

```bash
# Build
docker build -t gateway .

# Run
docker run -p 8080:8080 \
  -e DATABASE_URL="postgresql://..." \
  gateway
```

The container runs migrations automatically before starting the server.

---

## Deploy (Render)

Defined in `render.yaml`:

- Free tier web service
- PostgreSQL managed database attached via `DATABASE_URL`
- Health check at `/health`
- Docker build + `entrypoint.sh` runs migrations then starts `./gateway`

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection string (`postgresql://user:pass@host:5432/db`) |
| `PORT` | No | HTTP port (default: `8080`) |
