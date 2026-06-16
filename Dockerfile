# ─────────────────────────────────────────────
# ESTÁGIO 1: builder
# Imagem oficial do Haskell já vem com GHC + Cabal
# ─────────────────────────────────────────────
FROM haskell:9.6-slim-bookworm AS builder

WORKDIR /build

# Instala dependências de sistema necessárias para compilar
# libpq-dev  → postgresql-simple precisa dos headers do libpq
# pkg-config → algumas dependências C usam pkg-config para achar libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# ── Camada de cache para dependências Haskell ──────────────────────────
# Copiamos só os arquivos de definição de dependências primeiro.
# Se o .cabal não mudar, o Docker reutiliza o cache desta camada,
# evitando recompilar todas as libs em cada push de código.
COPY payment-gateway.cabal ./
RUN cabal update && cabal build --only-dependencies -j4

# ── Build do projeto ───────────────────────────────────────────────────
# Agora copiamos o código-fonte. Mudanças aqui não invalidam
# o cache das dependências acima.
COPY app/ ./app/
COPY src/ ./src/

RUN cabal build exe:payment-gateway -j4

# Localiza o binário compilado e copia para um lugar fixo.
# O path gerado pelo cabal inclui GHC version + hash, por isso usamos find.
RUN cp $(cabal list-bin payment-gateway) /build/payment-gateway-exe

# ─────────────────────────────────────────────
# ESTÁGIO 2: runtime mínimo
# Usamos debian:slim (mesma base da imagem haskell) para garantir
# compatibilidade de libc. Alpine usa musl e causaria problemas.
# ─────────────────────────────────────────────
FROM debian:bookworm-slim AS runtime

WORKDIR /app

# Dependências de runtime (sem headers de desenvolvimento)
# libpq5     → runtime do PostgreSQL client
# ca-certificates → para conexões TLS ao banco
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    postgresql-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copia o binário compilado do estágio builder
COPY --from=builder /build/payment-gateway-exe ./payment-gateway

# Copia as migrations para aplicar no entrypoint
COPY migrations/ ./migrations/

# Copia o script de entrypoint
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

# O Render injeta PORT automaticamente; 8080 é o fallback local
EXPOSE 8080

ENTRYPOINT ["./entrypoint.sh"]