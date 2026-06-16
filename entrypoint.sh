#!/bin/sh
set -e

if [ -z "$DATABASE_URL" ]; then
  echo "ERRO: variável DATABASE_URL não definida. Abortando."
  exit 1
fi

echo "Aplicando migrations..."

for migration in $(ls ./migrations/*.sql | sort); do
  echo "  → $migration"
  psql -d "$DATABASE_URL" -f "$migration" -v ON_ERROR_STOP=1
done

echo "Migrations aplicadas com sucesso."
echo "Iniciando payment-gateway..."
exec ./gateway