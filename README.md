# Ne manca 1 (nemanca1.com)

Web app per cellulare che aiuta a trovare giocatori per le partite di calcetto nei campi vicino a te.
Ogni campo ha un QR code: chi lo inquadra vede le partite in programma e può unirsi.

Stack: Vite + Svelte 5, Supabase (Postgres, Auth OTP, Realtime, RLS), Cloudflare Pages.

## Avvio in locale

```bash
npm install
cp .env.example .env   # inserisci URL e chiave anon di Supabase
npm run dev
```

Poi apri http://localhost:5173 con la vista mobile del browser (390 px).

## Documentazione

- `CLAUDE.md` – memoria del progetto: funzionamento, stack, schema, grafica, decisioni
- `ROADMAP.md` – stato delle tappe
- `docs/SETUP.md` – configurazione di Supabase, Resend e Cloudflare Pages
- `supabase/migrations/` – schema del database
- `docs/screenshot/` – schermate della Tappa 1 (dati finti)
