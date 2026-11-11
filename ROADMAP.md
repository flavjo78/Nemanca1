# App calcetto – Roadmap

Aggiornata l'11 novembre 2026 (prima sessione in Code).

Legenda: ✅ fatto · 🟡 fatto nel codice, da provare online · 🔴 da fare

## Tappa 1 – Base
- ✅ Progetto Vite + Svelte 5, grafica dal mockup (`src/app.css`), icone SVG a tratto
- ✅ Schema Supabase completo con RLS, viste e funzioni (`supabase/migrations/0001_schema.sql`)
- ✅ Login con codice OTP via email + completamento profilo (nome, comune, ruoli)
- ✅ Registrazione campo con geocoding Nominatim o posizione del telefono
- ✅ Pagina campo `/campo/<id>` pubblica, QR stampabile e condivisibile
- ✅ Creazione partita (formato 5/8/11, data, quota, descrizione, squadra e ruolo dell'organizzatore)
- ✅ Elenco partite del campo con posti occupati/liberi
- ✅ Home personale: prossima partita, richieste da approvare, partite vicine con posti liberi
- ✅ Schermata partita con campo disegnato e formazione (sola lettura), condivisione, annulla
- ✅ Profilo con voto, partite, vinte, barre per categoria, storico (vuoti finché non ci sono dati)
- 🟡 Provato solo con un Supabase simulato (Playwright, screenshot in `docs/screenshot/`): manca la prova con il progetto Supabase vero
- 🔴 Repo GitHub + deploy su Cloudflare Pages con dominio nemanca1.com (vedi `docs/SETUP.md`)
- 🔴 Supabase: creare il progetto, eseguire la migrazione, template email OTP con `{{ .Token }}`, SMTP Resend

## Tappa 2 – Campo disegnato
- 🔴 Prendere un posto libero toccandolo (la policy RLS "prendi posto" c'è già)
- 🔴 Candidatura per un ruolo + accettazione/rifiuto dell'organizzatore (tabella `richieste` pronta; la Home già mostra "Da approvare")
- 🔴 L'organizzatore modifica lo schema (aggiunge/sposta/toglie posti)
- 🔴 Cambio ruolo proposto → accetta/rifiuta (`stato = cambio_proposto`, `nuovo_ruolo_proposto`)
- 🔴 Partita → `completa` quando non ci sono più posti liberi

## Tappa 3 – Chat realtime e push
- 🔴 Chat per partita (tabella `messaggi` già in `supabase_realtime`), card richiesta nella chat
- 🔴 OneSignal web push

## Tappa 4 – Social
- 🔴 Giocatori vicini, inviti, mappa campi con Leaflet

## Tappa 5 – Dopo la partita
- 🔴 Inserimento risultato, recensioni anonime (vista `profili_voti` pronta), storico (vista `storico_partite` pronta)

## Tappa 6 – PWA e test sul campo
- 🟡 Manifest presente; manca il service worker per l'installazione offline
- 🔴 Test con 10 persone su un campo vero; poi padel/tennis

## Decisioni prese in questa sessione
Vedi la sezione "Decisioni" di `CLAUDE.md` (Svelte 5, haversine in SQL, pagine pubbliche dal QR, Tophost + Resend).
