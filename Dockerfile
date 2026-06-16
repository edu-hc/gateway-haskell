# ─────────────────────────────────────────────
# ESTÁGIO 1: builder
# ─────────────────────────────────────────────
FROM haskell:9.8.4-slim-bullseye AS builder

WORKDIR /build

# Instala libpq-dev >= 16 via repositório oficial do PostgreSQL.
# Necessário porque:
#   - postgresql-simple ^>=0.7 depende de postgresql-libpq ^>=0.11
#   - postgresql-libpq-0.11 exige libpq >= 14
#   - Debian Bullseye só tem PostgreSQL 13 nos repositórios padrão
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
       | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
       https://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" \
       > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# ── Camada de cache para dependências Haskell ──────────────────────────
COPY gateway.cabal ./
RUN cabal update && cabal build --only-dependencies -j4

# ── Build do projeto ───────────────────────────────────────────────────
COPY app/ ./app/
COPY src/ ./src/

RUN cabal build exe:gateway -j4

RUN cp $(cabal list-bin gateway) /build/gateway-exe

# ─────────────────────────────────────────────
# ESTÁGIO 2: runtime mínimo
# ─────────────────────────────────────────────
FROM debian:bullseye-slim AS runtime

WORKDIR /app

# libpq5 versão 16 no runtime também, para compatibilidade com o binário compilado
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
       | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] \
       https://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" \
       > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/gateway-exe ./gateway
COPY migrations/ ./migrations/
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["./entrypoint.sh"]