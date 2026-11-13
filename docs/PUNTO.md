# Il punto della situazione – Ne manca 1

Aggiornato: 13 novembre 2026, sera. Tutto quello che è nella sezione "Fatto" è online su **www.nemanca1.com**.
Questo file si aggiorna a ogni passaggio e si ripropone a Flavio.

## Fatto (online su www)

**Accesso e profilo**
- [x] Accesso con codice via email (Resend, mittente `benvenuto@nemanca1.com`), niente password
- [x] Profilo: nome **non modificabile** dopo la prima iscrizione (solo l'amministratore lo corregge), comune, ruoli preferiti
- [x] **Foto del giocatore** dalla fotocamera o dalla galleria, ridotta in automatico a pochi KB (anche HEIC dell'iPhone); visibile in profilo, Home e nei cerchi del campo

**Campi**
- [x] Registrazione campi con **QR** da stampare (apre la pagina del campo anche senza account)
- [x] **Mappa dei campi** (schede Lista/Mappa): segnaposto arancio con il numero di partite con posti liberi, cerchio dei km
- [x] **Raggio personalizzabile** ("Entro X km") nella pagina Campi e in Home, scelto da ogni giocatore

**Partite e campo disegnato**
- [x] Calcio a 5/8/11, quota, panchine; modalità "ognuno sceglie il suo posto" o "decido io chi gioca"
- [x] Formazione sul campo con **modulo a contatori** (sempre i giocatori del formato), cerchi da **trascinare**, "Posizionati qui"
- [x] Candidature con squadra e ruolo, cambio di ruolo che sposta il giocatore, **vice** per squadra, **tribuna**, panchina
- [x] **Divise**: colori di maglia e pantaloncini scelti dall'organizzatore, completino accanto al modulo, "Porta la maglia …"
- [x] **Giocate e archivio**: dopo un'ora la partita è "giocata", dal giorno dopo in archivio; non si cancella nulla

**Chat e notifiche**
- [x] **Chat** di ogni partita in tempo reale, con card Accetta/Rifiuta; si chiude solo quando la partita va in archivio
- [x] **Numero dei messaggi da leggere** sull'icona Chat (lampeggia piano se più di uno)
- [x] **Notifiche automatiche** (OneSignal): candidature, accettazioni, inviti, messaggi, cambi di ruolo, amicizie, nuovi iscritti (solo a Flavio); proposte da subito, si spengono dal Profilo

**Amici e social**
- [x] **Lista amici** (si diventa amici solo se l'altro accetta), ricerca per nome, "Hai giocato con"
- [x] **Invita amici / Invita tutti** dalla partita, anche per chi gioca e non organizza (nelle partite "decido io" decide sempre l'organizzatore)
- [x] **"Cercami per le partite"** in Home (spento finché il giocatore non lo accende)

**App**
- [x] Scheda **"Metti l'app sulla schermata Home"** (un tocco su Android, istruzioni su iPhone)
- [x] Riquadro **"Novità"** dopo ogni aggiornamento e avviso "versione nuova: tocca per aggiornare"
- [x] **Area amministratore** con numeri e termometro dello spazio (500 MB)
- [x] "Aiuto e supporto" → `supporto@nemanca1.com` (inoltro alla Gmail di Flavio)

**Infrastruttura**
- [x] Dominio **nemanca1.com** con lucchetto, anche senza www (GitHub Pages → www, HTTPS forzato)
- [x] Supabase (Irlanda, Free), Cloudflare Pages, Resend con dominio verificato, OneSignal con chiave nel Vault
- [x] **Autonomia via git**: Claude applica le modifiche al database da solo; controlli automatici su GitHub (app + database) a ogni pubblicazione; l'ambiente cloud installa da solo le librerie
- [x] Anteprima fissa su https://anteprima.nemanca1.pages.dev; due icone per le prove (verde = giocatore su www, nera = Admin su nemanca1.pages.dev)

## Da fare, in ordine

1. [ ] **Tappa 4 – ultimo pezzo**: avviso **"Serve un portiere vicino a te"** ai giocatori della zona con "Cercami" acceso e il ruolo giusto (usa le notifiche). Da completare anche: campi frequentati e disponibilità (facoltativa) nel profilo; chat 1-a-1 tra amici; "blocca"
2. [ ] **Tappa 5 – Dopo la partita**: risultato (andrà anche nell'archivio), recensioni anonime su 4 categorie, voti nel profilo, storico
3. [ ] **Tappa 6**: QR stampabili (versione da stampare con logo), prova con 10 persone su un campo vero
4. [ ] **Entra con Google**
5. [ ] **Sicurezza, per ultima**: revocare il primo token Supabase e rigenerare la chiave Resend (finiti in screenshot)

## Facoltativi

- [ ] **Scarica archivio** dalla pagina amministratore (chat, partite, utenti in un file) prima di qualsiasi pulizia
- [ ] **Supabase Pro** quando arrivano utenti regolari (più connessioni, niente pausa per inattività, backup giornalieri)
- [ ] Fornitore di mappe con chiave se il traffico della mappa cresce (policy OpenStreetMap)
- [ ] Pulizia delle chat di partite vecchie, solo se il database si avvicina ai 500 MB e dopo aver scaricato l'archivio
- [ ] Gmail: filtro per le email a `supporto@` (etichetta "Ne manca 1", mai in Spam) e "Invia come supporto@"
- [ ] Copia delle email di supporto@ anche su Tophost (Tophost non accetta due destinazioni: servirebbe un ticket)

## Decisioni recenti (dettagli in CLAUDE.md)

- I km non stanno nel profilo: bottone "Entro X km" in Campi e Home; "Cercami" è un interruttore in Home
- Il nome non si cambia dopo la prima iscrizione
- La chat si chiude solo quando la partita va in archivio (il giorno dopo)
- Le notifiche non si possono accendere senza il "Consenti" del telefono: l'app lo chiede subito e si spengono dal Profilo
- Può invitare amici anche chi gioca; nelle partite "decido io" l'invito diventa una candidatura
- A ogni "unisci" Claude aggiorna la lista delle Novità mostrata agli utenti
