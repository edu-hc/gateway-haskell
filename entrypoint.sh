#!/bin/sh
set -e

if [ -z "$DATABASE_URL" ]; then
  echo "ERRO: variável DATABASE_URL não definida. Abortando."
  exit 1
fi

psql -d "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "
  CREATE TABLE IF NOT EXISTS schema_migrations (
    filename TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
"

echo "Aplicando migrations..."

for migration in $(ls ./migrations/*.sql | sort); do
  filename=$(basename "$migration")
  already_applied=$(psql -d "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM schema_migrations WHERE filename = '$filename'")
  if [ "$already_applied" = "0" ]; then
    echo "  → $filename"
    psql -d "$DATABASE_URL" -f "$migration" -v ON_ERROR_STOP=1
    psql -d "$DATABASE_URL" -c "INSERT INTO schema_migrations (filename) VALUES ('$filename')"
  else
    echo "  ✓ $filename (já aplicada)"
  fi
done

echo "Migrations aplicadas com sucesso."
echo "Iniciando payment-gateway..."
exec ./gateway