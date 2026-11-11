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
- ✅ Progetto Supabase vero creato (Irlanda), migrazione eseguita, SMTP Resend + template OTP configurati, lettura e RLS verificate dall'app
- ✅ Repo GitHub flavjo78/Nemanca1 + deploy automatico su Cloudflare Pages: https://nemanca1.pages.dev
- 🔴 Dominio nemanca1.com agganciato a Pages (dopo il DNS su Cloudflare)
- 🔴 Resend: verificare il dominio nemanca1.com (dopo il DNS su Cloudflare) e passare il mittente a `noreply@nemanca1.com`; rigenerare la API key

## Tappa 2 – Campo disegnato (✅ online su www.nemanca1.com, con tribuna, panchine, modulo a contatori, trascinamento, vice di squadra)
- ✅ Prendere, lasciare, spostarsi di posto toccando il campo (`prendi_posto`, `lascia_posto`)
- ✅ Candidatura per un ruolo + accetta/rifiuta dell'organizzatore, con assegnazione automatica del posto (`candidati`, `rispondi_richiesta`)
- ✅ Schema modificabile: aggiungi/togli posti, cambia ruolo di un posto libero (`aggiungi_posto`, `rimuovi_posto`); disposizione automatica in righe per ruolo
- ✅ Cambio ruolo proposto → il giocatore accetta o rifiuta (`proponi_cambio`, `rispondi_cambio`)
- ✅ Partita `completa`/`aperta` automatica (trigger), aggiornamento in tempo reale della schermata
- ✅ Messaggi di sistema in `messaggi` per ogni evento (pronti per la chat della tappa 3)
- ✅ Pagina amministratore `/admin` e script `scripts/backup.sh`

## Tappa 3 – Chat realtime e push
- 🔴 Chat per partita (tabella `messaggi` già in `supabase_realtime`), card richiesta nella chat
- 🔴 OneSignal web push

## Tappa 4 – Social
- 🔴 Giocatori vicini, inviti, mappa campi con Leaflet

## Tappa 5 – Dopo la partita
- 🔴 Inserimento risultato, recensioni anonime (vista `profili_voti` pronta), storico (vista `storico_partite` pronta)

## Tappa 6 – PWA e test sul campo
- ✅ Manifest presente; manca il service worker per l'installazione offline
- 🔴 Test con 10 persone su un campo vero; poi padel/tennis

## Decisioni prese in questa sessione
Vedi la sezione "Decisioni" di `CLAUDE.md` (Svelte 5, haversine in SQL, pagine pubbliche dal QR, Tophost + Resend).
