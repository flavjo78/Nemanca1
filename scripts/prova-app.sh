#!/usr/bin/env bash
# Costruisce l'app con un Supabase finto e la prova nel browser (tests/smoke.cjs).
# Non tocca il database vero. Uso: scripts/prova-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VITE_SUPABASE_URL=https://finto.supabase.co VITE_SUPABASE_ANON_KEY=finta npx vite build --outDir dist-prova --emptyOutDir >/dev/null
npx vite preview --outDir dist-prova --port 4173 --strictPort >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
for i in $(seq 1 30); do curl -s -o /dev/null http://localhost:4173/ && break; sleep 0.5; done
node tests/smoke.cjs
