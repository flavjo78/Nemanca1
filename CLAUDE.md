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
- **Backend**: **Supabase** (Postgres, Auth, Realtime, Storage, RLS). Progetto `nemanca1`, regione **eu-west-1 (Irlanda)** (il pannello non offriva Francoforte sul piano Free). Login: email con codice OTP; Google OAuth in seguito.
- **Hosting**: **Cloudflare Pages**, deploy automatico da GitHub.
- **Dominio**: **nemanca1.com** comprato su Tophost (TopName). Tophost **non permette di cambiare i nameserver**, quindi il DNS resta su Tophost: l'app risponde su `https://www.nemanca1.com` (CNAME verso Pages); `nemanca1.com` punta (4 record A) a **GitHub Pages**, repository `flavjo78/nemanca1-redirect`, una pagina che rimanda a www conservando percorso e parametri. Flavio ha deciso di non trasferire il dominio: `www.nemanca1.com` è l'indirizzo definitivo. email automatiche da **`benvenuto@nemanca1.com`** (Resend, scelto da Flavio l'11/11) e **`supporto@nemanca1.com`** (inoltro esterno su Tophost verso la Gmail di Flavio; Tophost ha una sola MAILBOX `nemanca1.com` con webmaster@/postmaster@; nessun alias da `benvenuto@`).
- **Email transazionali**: **Resend** (SMTP custom in Supabase Auth); dominio autenticato con SPF/DKIM. Non usare Gmail né Amazon SES.
- **Push**: **OneSignal** (web push).
- **Mappe**: **OpenStreetMap + Leaflet**; geocoding con Nominatim; distanza calcolata lato DB (PostGIS o formula haversine).
- **QR**: libreria `qrcode` lato client; il QR codifica l'URL `https://www.nemanca1.com/campo/<id>?qr=1` (l'app usa `location.origin`, quindi segue il dominio da cui è aperta).

Chiavi e URL vanno in `.env` (mai nel repo). Variabili attese: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` (si usa la chiave **publishable** `sb_publishable_...`, pubblica per design), `VITE_ONESIGNAL_APP_ID`.

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
- **Logo** (variante 5 scelta da Flavio l'11/11): scritta "Ne manca" in **Outfit 900** inclinata di 8° in avanti + l'**1** (Space Grotesk) dentro un cerchio tratteggiato (lo stesso del posto libero sul campo). Slogan: **"Trova chi manca in campo"** (Inter 600, maiuscolo spaziato, verde o verde chiaro). Versione verticale (cerchio sopra la scritta) per QR stampati e splash. Componente `src/components/Logo.svelte` (prop `slogan`, `verticale`, `chiaro`); icona app `public/icona.svg` (+ PNG 192/512 e versione maskable). Anteprima in `docs/logo-anteprima.png`.

## Tappe

1. Base: login OTP, registrazione campo, QR, creazione partita, elenco partite del campo, Home.
2. Campo disegnato: formazione 5/8/11, posti liberi, candidatura, accettazione, cambio ruolo da confermare.
3. Chat realtime e push.
4. Social: giocatori vicini, inviti, mappa campi.
5. Dopo partita: risultato, recensioni, voti, storico.
6. PWA installabile, QR stampabili, test con 10 persone su un campo vero. Poi padel/tennis.

## Regole di lavoro

- **Anteprime**: pubblicare sempre le novità da provare sul ramo **`anteprima`** (indirizzo fisso `https://anteprima.nemanca1.pages.dev`), così Flavio fa il login una volta sola. Dopo l'ok ("unisci") si porta il ramo su `main`.
- **Migrazioni del database**: le applica Claude con `scripts/applica-migrazione.sh <file>` (Management API di Supabase; il token è un segreto dell'ambiente cloud "nemanca1", iniettato dal proxy su api.supabase.com). Non chiedere a Flavio di incollare SQL. Ogni nuovo file va in `supabase/migrations/` con numero progressivo e deve essere rieseguibile senza errori.

- Ogni tappa termina con qualcosa di provabile sul telefono (deploy su Cloudflare Pages).
- Commit piccoli con messaggi in italiano.
- Non mettere dati personali di Flavio (indirizzo, codice fiscale) in file o pagine pubbliche.
- Aggiornare ROADMAP.md a fine sessione: cosa è fatto, cosa resta, decisioni prese.
- **`docs/PUNTO.md`** è l'elenco vivo di cosa è fatto, in corso e da fare, comprese le richieste di Flavio: aggiornarlo a ogni passaggio, committarlo e riproporlo in chat quando serve.

## Decisioni

- 2026-11-10: Supabase + Cloudflare Pages + Resend + OneSignal + OSM/Leaflet; si parte gratis, Supabase Pro solo quando serve.
- 2026-11-10: recensioni anonime; chat 1-a-1 limitata a chi ha giocato insieme o ha un invito.
- 2026-11-11: grafica approvata dal mockup (vedi sezione Grafica).
- 2026-11-11: frontend in **Svelte 5** (runes) + Vite 8, router fatto in casa (`src/lib/router.svelte.js`), nessuna libreria UI. Stile in `src/app.css` con i token del mockup.
- 2026-11-11: distanze con formula haversine in SQL (`distanza_km`), niente PostGIS per ora. Funzioni RPC: `crea_partita` (crea partita + posti predefiniti + siede l'organizzatore), `partite_vicine`, `campi_vicini`.
- 2026-11-11: la pagina `/campo/<id>` e `/partita/<id>` sono pubbliche (si aprono dal QR senza login); tutto il resto richiede il login. Il QR codifica `/campo/<id>?qr=1`.
- 2026-11-11: dominio su Tophost con DNS su Cloudflare; casella `info@` su Tophost, invii automatici con Resend da `noreply@`.
- 2026-11-11: dominio acquistato **nemanca1.com**; nome dell'app "Ne manca 1" (da confermare con Flavio), usato in titolo, manifest e schermata di login.
- 2026-11-11: Supabase creato (Irlanda), migrazione eseguita, SMTP Resend attivo con mittente provvisorio `onboarding@resend.dev` (consegna solo alla mail di Flavio finché il dominio non è su Resend). Template "Confirm sign up" e "Magic link or OTP" con `{{ .Token }}`. Senza SMTP custom Supabase non lascia modificare i template.
- 2026-11-11: Tophost non consente di modificare i record NS: DNS resta su Tophost, app su www.nemanca1.com, redirect dal dominio nudo, record Resend inseriti a mano su Tophost.
- 2026-11-11: dominio verificato su Resend (DKIM + SPF + DMARC su Tophost). Mittente delle email automatiche: `benvenuto@nemanca1.com`.
- 2026-11-11: Tappa 2: tutte le azioni sul campo passano da funzioni SQL `security definer` (controlli e messaggi di sistema lato DB, niente update diretti dal client). Posizioni disposte dal client in righe per ruolo (`src/lib/formazione.js`); x/y nel DB restano indicativi. Amministratore = `profili.admin`, assegnato al primo iscritto.
- 2026-11-11: **Tribuna** (tabella `tribuna`: segue la partita e la chat senza giocare), **modalità** `partite.modalita` = `libera` (ognuno si siede) o `approvazione` (assegna l'organizzatore: candidature o "chiedi di giocare" con invito da accettare), **panchine** come posizioni con ruolo `panchina` (`partite.panchina` riserve per squadra), mostrate a lato del campo; non contano per lo stato "completa". La lista amici vera arriverà con la tappa 4.
- 2026-11-11: **Modulo** scelto alla creazione (`p_modulo`, es. 1-2-2 / 1-1-3 / 1-1-2-1; elenco in `src/lib/formazione.js` → MODULI) e cambiabile per squadra con `cambia_modulo` (chi è in campo resta in campo). **Sposta/scambia** giocatori con `sposta_giocatore`. **Vice** per squadra (tabella `vice`, colonna `squadra`): gestisce modulo e posizioni solo della sua squadra (`puo_gestire_squadra`); l'organizzatore gestisce entrambe e nomina i vice. Con modalità `approvazione` il cambio di ruolo è diretto, senza conferma. Panchine: a lato del campo su schermi larghi, sopra/sotto in orizzontale sotto i 480px. Bottone "copia link" nella partita.
- 2026-11-11: Modulo **senza portiere** (sempre 1) e scelto con **tre contatori** Difesa/Centrocampo/Attacco (`src/components/Contatori.svelte`), niente elenco di moduli fissi. Il modulo si mostra sul campo: in alto a destra per la squadra A, in basso a destra per la B. Nel DB resta la forma `1-d-c-a` (`moduloPerDb`), nei messaggi `testo_modulo`.
- 2026-11-11: **Formazione trascinando i cerchi** (pressione lunga 0,7 s, `TEMPO_PRESSIONE` in `CampoDisegnato.svelte`): il ruolo si deduce dall'altezza nella metà campo (`ruolo_da_altezza`: <47 difesa, <73 centrocampo, oltre attacco), il portiere resta in porta e si sposta solo di lato. Posti spostati a mano hanno `posizioni.manuale = true` e coordinate x/y salvate; al primo trascinamento il client fissa anche gli altri della squadra (`fissa_posti`). Cambiando modulo con i contatori la squadra torna automatica.
- 2026-11-11: Sotto i cerchi occupati: **cognome + iniziale del nome** (`nomeCampo`), "Tu" per sé; il ruolo si capisce dalla posizione. I cerchi si muovono solo con trascinamento o cambio modulo; spostare un giocatore o chiamarlo dalla tribuna usa un **selettore a passi** squadra → ruolo → quale cerchio (a sinistra/al centro/a destra, panchina posto 1-2…).
- 2026-11-11: **Chat** (tappa 3): `/chat` elenco (`mie_chat()`, pallino "nuovo" da `src/lib/letture.js` su localStorage), `/chat/<id>` in tempo reale (Supabase Realtime su `messaggi`). Scrivono solo messaggi `testo` (policy); i messaggi di sistema/richiesta/cambio_ruolo li crea il DB e diventano card con Accetta/Rifiuta. Accesso con `partecipa()` = organizzatore, vice, giocatori, panchina, tribuna, chi ha un invito. Testo 1-1000 caratteri. "Aiuto e supporto" (mailto supporto@nemanca1.com) nel Profilo e nel login.
- 2026-11-11: `nome_breve` (nomi nei messaggi di sistema): "Marco R." con nome e cognome, solo il nome se il profilo ne ha uno (prima diventava "Un giocatore"). Nella chat la card della candidatura mostra il nome completo letto dalla richiesta.
- 2026-11-11: **Candidatura con preferenza di squadra** (`richieste.squadra_preferita`, A/B/null = qualsiasi): accettando si cerca prima nella squadra preferita, poi nell'altra; chi non indica il ruolo va in porta solo se non c'è altro. Icona "formazione" (campetto) per andare dalla chat al campo, al posto del segnaposto.
- 2026-11-11: **Termometro** dello spazio nella pagina amministratore (`admin_spazio()`, limite 500 MB del piano gratuito). Nessun dato viene cancellato in automatico: partite e chat si conservano; quando servirà spazio si scarica l'archivio (bottone da fare, oggi `scripts/backup.sh`) prima di qualsiasi pulizia, decisa da Flavio.
- 2026-11-12: **Cambio di ruolo di un giocatore** = il giocatore va su un cerchio libero di quel ruolo nella sua squadra (`applica_cambio_ruolo`); se non c'è, il suo cerchio diventa del nuovo ruolo e, se la squadra è disposta a mano, scende/sale nella fascia giusta (`altezza_ruolo`). In modalità libera resta la proposta da accettare; lo spostamento avviene all'accettazione.
- 2026-11-12: **I giocatori in campo per squadra sono sempre quelli del formato** (5/8/11, portiere compreso): `cambia_modulo` richiede che il modulo sommi formato−1, `aggiungi_posto`/`rimuovi_posto` in campo bloccati oltre/sotto il formato; si aggiungono e tolgono solo riserve in panchina. Migrazione 0014; sistemata una partita di prova che aveva 6 posti in B.
- 2026-11-12: **Notifiche push** con OneSignal (piano Free, App ID pubblico nel codice `src/lib/notifiche.svelte.js`, sovrascrivibile con `VITE_ONESIGNAL_APP_ID`). Funzionano solo su `https://www.nemanca1.com` (un sito per app OneSignal). Il dispositivo è collegato con `OneSignal.login(id utente)` (external_id = profili.id), così il DB invia per id. Nessuna richiesta automatica: scheda Notifiche nel Profilo e riquadro dopo candidatura/ingresso in squadra. Su iPhone servono app aggiunta alla Home e iOS 16.4+.
- 2026-11-12: **Tappa 4** approvata: ordine profilo zona → mappa campi → giocatori vicini e inviti → compagni/chat 1-a-1/blocca → "serve un portiere vicino a te". Il **raggio di ricerca lo sceglie ogni giocatore** (personalizzabile, non un valore fisso). Prima della Tappa 4 si completano le notifiche automatiche (chiave REST OneSignal nel Vault di Supabase, invio dal DB con pg_net).
- 2026-11-12: **Il nome del profilo non si cambia** dopo il primo salvataggio (trigger `profili_blocca_nome`, migrazione 0015; eccezioni: amministratore o intervento diretto sul DB). In modifica profilo il campo è in sola lettura con rimando a supporto@. Bottone del posto libero: **"Posizionati qui"** (scelto da Flavio).
- 2026-11-12: **Giocate e archivio** (migrazione 0016): un'ora dopo l'inizio la partita passa a `stato = giocata` (esce dagli elenchi aperti, non è più modificabile, la chat è in sola lettura: `chat_attiva()` nella policy di insert dei messaggi); dal giorno dopo (ora italiana) `partite.archiviata = true`. Lo fa `aggiorna_stati_partite()` ogni 5 minuti con **pg_cron** (job `aggiorna-stati-partite`). **Nulla si cancella**: formazione, modulo, partecipanti, panchina, tribuna, chat e risultato restano. Pagina `/giocate` (schede Giocate/Archivio, RPC `mie_partite_passate`), link dal Profilo; `mie_chat()` mostra anche le chat chiuse (etichetta Chiusa/Archivio).
