# App calcetto – istruzioni per Claude Code

Questo file è la memoria del progetto. Leggilo all'inizio di ogni sessione. Le decisioni nuove vanno aggiunte qui (sezione "Decisioni") e in ROADMAP.md.

## Cos'è l'app

Nome: **Ne manca 1** (dominio nemanca1.com). Web app (PWA) per cellulare che aiuta a trovare giocatori per partite di calcetto (calcio a 5, 8, 11); padel e tennis in seguito.

Funzionamento:
1. **Campi**: si registra un campo sportivo (nome, indirizzo, posizione, sport). Ogni campo ha un **QR code** da attaccare in loco; chi lo inquadra apre `/campo/<id>` e vede le partite di quel campo.
2. **Partite**: un utente (organizzatore) crea una partita su un campo: giorno, ora, formato (5/8/11), descrizione, quota a testa, posti e ruoli mancanti.
3. **Formazione sul campo disegnato**: la schermata della partita mostra un campo da calcio con le due squadre in formazione. L'organizzatore decide lo schema (quanti posti e dove); ogni giocatore si siede nel posto libero che preferisce. L'organizzatore può proporre a un giocatore un cambio di ruolo: il giocatore deve **accettare o rifiutare**. Ogni posizione ha uno stato: libera → occupata → cambio proposto → confermata.
4. **Entrare in partita**: un utente può iscriversi come partecipante in un posto libero, oppure candidarsi per un ruolo mancante (es. portiere); l'organizzatore accetta o rifiuta (stile BlaBlaCar).
5. **Chat interna**: ogni partita ha una chat in tempo reale visibile solo ai partecipanti accettati. Le richieste di ingresso e le proposte di cambio ruolo compaiono nella chat come card con Accetta/Rifiuta.
6. **Giocatori vicini e inviti**: ogni iscritto indica zona e campi frequentati. L'organizzatore vede i giocatori della zona e li invita; l'invito arriva come notifica. Chat 1-a-1 solo tra chi ha giocato insieme o ha un invito in corso.
7. **Dopo la partita**: si inserisce il risultato; ogni partecipante recensisce gli altri su 4 categorie (puntualità, correttezza, livello tecnico, spirito di squadra, 1–5). Le recensioni sono **anonime**: si vede solo la media.
8. **Profilo e storico**: voto complessivo e per categoria, partite giocate/vinte, storico con risultato e compagni, campi frequentati.
9. **Notifiche push**: "serve un portiere vicino a te", "sei stato accettato", "nuovo messaggio", "ti hanno invitato".

Monetizzazione futura (l'app resta gratuita per i giocatori): campi "verificati" a abbonamento, sponsor del campo, prenotazione dell'ora con commissione, funzioni premium per organizzatori. Prevedere già nello schema: `campi.verificato`, `campi.sponsor`, tabella `prenotazioni`.

## Stack scelto

- **Frontend**: HTML/CSS/JS in Vite + framework leggero (Svelte o React, scegliere nella prima sessione) come PWA; mobile-first 390px.
- **Backend**: **Supabase** (Postgres, Auth, Realtime, Storage, RLS). Regione eu-central (Francoforte). Login: email con codice OTP; Google OAuth in seguito.
- **Hosting**: **Cloudflare Pages**, deploy automatico da GitHub.
- **Dominio**: **nemanca1.com** (acquistato), DNS su Cloudflare. L'app risponde su `https://nemanca1.com`; email `noreply@nemanca1.com` (Resend) e `info@nemanca1.com` (casella umana).
- **Email transazionali**: **Resend** (SMTP custom in Supabase Auth); dominio autenticato con SPF/DKIM. Non usare Gmail né Amazon SES.
- **Push**: **OneSignal** (web push).
- **Mappe**: **OpenStreetMap + Leaflet**; geocoding con Nominatim; distanza calcolata lato DB (PostGIS o formula haversine).
- **QR**: libreria `qrcode` lato client; il QR codifica l'URL `https://nemanca1.com/campo/<id>?qr=1`.

Chiavi e URL vanno in `.env` (mai nel repo). Variabili attese: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_ONESIGNAL_APP_ID`.

## Schema dati (Supabase)

- `profili` (id = auth.users.id, nome, iniziali, comune, lat, lng, ruoli_preferiti[], creato_il)
- `campi` (id, nome, indirizzo, lat, lng, sport[], verificato bool, sponsor_nome, sponsor_testo, creato_da)
- `partite` (id, campo_id, organizzatore_id, sport, formato 5|8|11, data_ora, descrizione, quota, stato aperta|completa|giocata|annullata, risultato_a, risultato_b)
- `posizioni` (id, partita_id, squadra A|B, ruolo portiere|difesa|centro|attacco, x, y, stato libera|occupata|cambio_proposto, giocatore_id, nuovo_ruolo_proposto)
- `richieste` (id, partita_id, giocatore_id, ruolo_richiesto, stato in_attesa|accettata|rifiutata)
- `inviti` (id, partita_id, da_id, a_id, stato)
- `messaggi` (id, partita_id, autore_id, testo, tipo testo|sistema|richiesta|cambio_ruolo, creato_il)
- `recensioni` (id, partita_id, da_id, a_id, puntualita, correttezza, livello, squadra) – unique (partita_id, da_id, a_id)
- `prenotazioni` (id, campo_id, partita_id, inizio, fine, stato) – per il futuro
- Viste: `profili_voti` (medie per categoria e complessiva per profilo), `storico_partite` per utente.

RLS: tutti leggono campi e partite aperte; messaggi leggibili/scrivibili solo da chi ha una posizione occupata nella partita o ne è organizzatore; recensioni scrivibili solo dai partecipanti di una partita in stato `giocata`, una per coppia.

## Grafica (dal mockup approvato)

- Font: Inter (testo), Space Grotesk 700 (titoli).
- Colori: sfondo `#F2F5F1`, superfici `#FFFFFF`, testo `#14201A`, testo secondario `#5B6B62`, verde primario `#1E7B4E`, verde chiaro `#BFE3CC`, arancio avviso (posti mancanti) `#FFF1DE` su testo `#9A4B0A`, badge portiere `#F0B35B`, "da confermare" `#C2570A`, campo da gioco `#2E8B57` a strisce con righe bianche.
- Componenti: card con raggio 16px; bottoni 52px raggio 14px; chip a pillola; barra inferiore con Home, Campi, Chat, Profilo.
- Schermate: Home (prossima partita, da approvare, partite vicine con posti liberi), Campo dal QR (lista partite del campo + organizza qui), Partita (campo disegnato con formazione, posto libero tratteggiato, badge "?" per cambio proposto, legenda, bottone Candidati), Chat (bolle + card richiesta con Accetta/Rifiuta + messaggi di sistema), Profilo (voto, partite, vinte, barre per categoria, storico con risultato, campi frequentati).
- Niente emoji nelle icone: SVG a tratto. Target touch minimo 44px.
- **Logo** (variante 5 scelta da Flavio l'11/11): scritta "Ne manca" in **Outfit 900** inclinata di 8° in avanti + l'**1** (Space Grotesk) dentro un cerchio tratteggiato (lo stesso del posto libero sul campo). Componente `src/components/Logo.svelte`; icona app `public/icona.svg` (+ PNG 192/512 e versione maskable). Anteprima in `docs/logo-anteprima.png`.

## Tappe

1. Base: login OTP, registrazione campo, QR, creazione partita, elenco partite del campo, Home.
2. Campo disegnato: formazione 5/8/11, posti liberi, candidatura, accettazione, cambio ruolo da confermare.
3. Chat realtime e push.
4. Social: giocatori vicini, inviti, mappa campi.
5. Dopo partita: risultato, recensioni, voti, storico.
6. PWA installabile, QR stampabili, test con 10 persone su un campo vero. Poi padel/tennis.

## Regole di lavoro

- Ogni tappa termina con qualcosa di provabile sul telefono (deploy su Cloudflare Pages).
- Commit piccoli con messaggi in italiano.
- Non mettere dati personali di Flavio (indirizzo, codice fiscale) in file o pagine pubbliche.
- Aggiornare ROADMAP.md a fine sessione: cosa è fatto, cosa resta, decisioni prese.

## Decisioni

- 2026-11-10: Supabase + Cloudflare Pages + Resend + OneSignal + OSM/Leaflet; si parte gratis, Supabase Pro solo quando serve.
- 2026-11-10: recensioni anonime; chat 1-a-1 limitata a chi ha giocato insieme o ha un invito.
- 2026-11-11: grafica approvata dal mockup (vedi sezione Grafica).
- 2026-11-11: frontend in **Svelte 5** (runes) + Vite 8, router fatto in casa (`src/lib/router.svelte.js`), nessuna libreria UI. Stile in `src/app.css` con i token del mockup.
- 2026-11-11: distanze con formula haversine in SQL (`distanza_km`), niente PostGIS per ora. Funzioni RPC: `crea_partita` (crea partita + posti predefiniti + siede l'organizzatore), `partite_vicine`, `campi_vicini`.
- 2026-11-11: la pagina `/campo/<id>` e `/partita/<id>` sono pubbliche (si aprono dal QR senza login); tutto il resto richiede il login. Il QR codifica `/campo/<id>?qr=1`.
- 2026-11-11: dominio su Tophost con DNS su Cloudflare; casella `info@` su Tophost, invii automatici con Resend da `noreply@`.
- 2026-11-11: dominio acquistato **nemanca1.com**; nome dell'app "Ne manca 1" (da confermare con Flavio), usato in titolo, manifest e schermata di login.
