#!/usr/bin/env bash
# Prova tutte le migrazioni su un Postgres vuoto, nell'ordine, ognuna due volte di fila
# (devono funzionare e devono essere rieseguibili senza errori).
# Uso: DATABASE_URL=postgres://... scripts/prova-migrazioni.sh
# NON usare la stringa del database vero: serve un database di prova vuoto.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DATABASE_URL:?serve DATABASE_URL di un database di prova vuoto}"
case "$DATABASE_URL" in *supabase.co*|*supabase.com*) echo "Questo script non va usato sul database vero."; exit 1;; esac

psql "$DATABASE_URL" -q -v ON_ERROR_STOP=1 -f tests/db/stub.sql
for f in supabase/migrations/*.sql; do
  for giro in 1 2; do   # ogni migrazione due volte di fila: deve essere rieseguibile
    psql "$DATABASE_URL" -q -v ON_ERROR_STOP=1 -f "$f" >/dev/null 2>/tmp/migrazione.err || {
      echo "ERRORE in $f (esecuzione $giro):"; grep -v "NOTICE\|WARNING\|HINT" /tmp/migrazione.err; exit 1; }
  done
  echo "ok  $f"
done
echo "Tutte le migrazioni applicate e rieseguibili."
