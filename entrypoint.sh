#!/bin/sh
# entrypoint.sh
#
# Responsabilidades:
#   1. Valida que DATABASE_URL está definida
#   2. Aplica migrations em ordem (idempotente por IF NOT EXISTS / CREATE TABLE IF NOT EXISTS)
#   3. Sobe o servidor
#
# Usar 'set -e' garante que qualquer falha para o container imediatamente,
# impedindo o servidor de subir com banco inconsistente.
set -e

# ── Validação de variáveis obrigatórias ───────────────────────────────
if [ -z "$DATABASE_URL" ]; then
  echo "ERRO: variável DATABASE_URL não definida. Abortando."
  exit 1
fi

# ── Aplica migrations via psql ─────────────────────────────────────────
# O Render provisiona o PostgreSQL com a DATABASE_URL no formato:
#   postgresql://user:pass@host:5432/dbname
# psql aceita esse formato diretamente com -d.
#
# ATENÇÃO PCI: nunca logue o conteúdo de DATABASE_URL.
echo "Aplicando migrations..."

for migration in ./migrations/*.sql; do
  echo "  → $migration"
  psql -d "$DATABASE_URL" -f "$migration" -v ON_ERROR_STOP=1
done

echo "Migrations aplicadas com sucesso."

# ── Inicia o servidor ─────────────────────────────────────────────────
echo "Iniciando payment-gateway..."
exec ./gateway