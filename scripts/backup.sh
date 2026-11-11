#!/usr/bin/env bash
# Backup del database Supabase: scarica ogni tabella in un file CSV.
#
# Uso (dal computer, serve psql installato):
#   export DATABASE_URL='postgresql://postgres.<ref>:<password>@aws-0-eu-west-1.pooler.supabase.com:5432/postgres'
#   ./scripts/backup.sh
#
# La stringa si copia da Supabase → bottone "Connect" in alto → "Session pooler".
# La password è quella del database (Project Settings → Database → Reset se persa).
# I file finiscono in backup/<data_ora>/ (cartella esclusa da git).
set -euo pipefail
: "${DATABASE_URL:?Imposta DATABASE_URL con la stringa di connessione di Supabase}"
dir="backup/$(date +%Y-%m-%d_%H%M)"
mkdir -p "$dir"
for t in profili campi partite posizioni richieste inviti messaggi recensioni prenotazioni; do
  psql "$DATABASE_URL" -q -Atc "\\copy (select * from public.$t) to '$dir/$t.csv' csv header"
  printf '%-12s %s righe\n' "$t" "$(($(wc -l < "$dir/$t.csv") - 1))"
done
echo "Backup salvato in $dir"
