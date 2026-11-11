#!/usr/bin/env bash
# Applica un file SQL al database Supabase tramite la Management API.
# Uso: ./scripts/applica-migrazione.sh supabase/migrations/0004_qualcosa.sql
# Nella sessione cloud di Claude il token (api.supabase.com) è iniettato dal proxy.
# Dal proprio computer: export SUPABASE_ACCESS_TOKEN=sbp_... prima di lanciarlo.
set -euo pipefail
file="${1:?Indica il file SQL da applicare}"
ref="vplzkjxgikpxewxkzanz"
corpo=$(python3 -c "import json,sys;print(json.dumps({'query':open(sys.argv[1]).read()}))" "$file")
auth=()
[ -n "${SUPABASE_ACCESS_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN")
risposta=$(curl -s -w '\n%{http_code}' -X POST "https://api.supabase.com/v1/projects/$ref/database/query" \
  -H "Content-Type: application/json" "${auth[@]}" --data "$corpo")
codice=$(tail -n1 <<< "$risposta")
echo "$(head -n -1 <<< "$risposta")"
[ "$codice" -lt 300 ] && echo "OK: $file applicato" || { echo "ERRORE $codice applicando $file"; exit 1; }
