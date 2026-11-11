# Il punto della situazione – Ne manca 1

Aggiornato: 11 novembre 2026, sera: tutto provato dal telefono, resta solo il rimbalzo https del nome nudo. Questo file si aggiorna a ogni passaggio e si ripropone a Flavio.

## Fatto

**Progetto e codice**
- [x] Progetto creato: Vite + Svelte 5, grafica dal mockup, icone SVG
- [x] Tappa 1 costruita: login con codice, profilo, Home personale, campi, nuovo campo, pagina campo con QR, nuova partita, partita col campo disegnato, profilo
- [x] Schema del database (tabelle, viste, funzioni, regole di sicurezza) provato su un Postgres locale
- [x] Logo: scritta "Ne manca" (variante 5, Outfit inclinata) + l'1 nel cerchio tratteggiato; slogan "Trova chi manca in campo"; icona app
- [x] Documentazione: CLAUDE.md, ROADMAP.md, README.md, docs/SETUP.md

**Account e servizi**
- [x] Dominio **nemanca1.com** acquistato su Tophost (prodotto TopName, attivo)
- [x] Repository GitHub **flavjo78/Nemanca1** creato, codice caricato
- [x] Supabase: organizzazione "Ne manca 1", progetto `nemanca1` (Irlanda, piano Free)
- [x] Supabase: file SQL eseguito, database pronto
- [x] Resend: account creato, API key generata
- [x] Supabase: SMTP collegato a Resend (mittente provvisorio onboarding@resend.dev)
- [x] Supabase: template email "Confirm sign up" e "Magic link or OTP" con il codice a 6 cifre
- [x] App configurata con URL e chiave publishable; lettura e sicurezza verificate sul database vero
- [x] **Cloudflare Pages**: app pubblicata su https://nemanca1.pages.dev, deploy automatico da GitHub, variabili Supabase impostate
- [x] **www.nemanca1.com attivo**: CNAME su Tophost, dominio verificato su Cloudflare Pages, HTTPS funzionante
- [x] **Resend: dominio nemanca1.com verificato** (DKIM, SPF, DMARC inseriti su Tophost): può spedire a chiunque
- [x] **Mittente `benvenuto@nemanca1.com` attivo**: login provato da un secondo indirizzo, email arrivata. **Gli amici possono entrare.**
- [x] Prova completa dal telefono di Flavio: tutto funziona (login, profilo, campi, partita)
- [x] Supabase → URL Configuration: Site URL `https://www.nemanca1.com`, Redirect URLs www e pages.dev
- [x] **Login provato per davvero**: email arrivata via Resend, codice (8 cifre) accettato, profilo creato in automatico

## In corso

- [ ] **Dominio, piano B** (Tophost non permette di cambiare i nameserver):
  1. ~~Tophost DNS: CNAME `www`~~ fatto
  2. ~~Cloudflare Pages → Custom domains → `www.nemanca1.com`~~ fatto
  3. Nome nudo `nemanca1.com`: Tophost lo rimanda già a www in **http** (301). In **https** il server Tophost presenta un certificato di un altro dominio, quindi alcuni browser mostrano un avviso. La funzione "Redirect dominio" di Tophost non è usabile (richiede `www` su Tophost). Soluzione pulita pronta: sito di rimbalzo su **GitHub Pages** (file già preparati in `/home/user/nemanca1-redirect`), serve il repo `flavjo78/nemanca1-redirect` + record `A` di `@` verso gli IP GitHub. Priorità bassa.
  4. ~~Resend → Domains → `nemanca1.com`~~ fatto

## Da fare, in ordine

1. [ ] Supabase → URL Configuration: mettere l'indirizzo dell'app pubblicata
3. [ ] Prima prova dal telefono: login, profilo, registrare un campo, stampare il QR, creare una partita
2. [ ] Cloudflare: cancellare la zona `nemanca1.com` rimasta "pending" (o tenerla per il trasferimento)
3. [ ] Casella `info@nemanca1.com` e alias su Tophost
4. [ ] **Resend**: verificare il dominio (SPF + DKIM su Cloudflare), mittente `noreply@nemanca1.com`, rigenerare la API key e cancellare quella mostrata in chat
6. [x] **Migrazione 0002 eseguita su Supabase l'11/11 sera** (verificato: le funzioni rispondono).
   [x] **Tappa 2 scritta e provata** (ramo `tappa-2`): prendere/lasciare/spostarsi di posto toccando il campo, candidature con accetta/rifiuta, cambio ruolo da confermare, aggiungere/togliere posti, partita "completa" automatica, aggiornamento in tempo reale. **Per attivarla**: eseguire `supabase/migrations/0002_tappa2.sql` nell'SQL Editor, poi unire il ramo su `main`
6b. [x] **Tappa 2 pubblicata su www.nemanca1.com** (unita su `main` l'11/11 sera)
6c. [x] **Tribuna, "decido io chi gioca", panchine** (richiesto l'11/11, ramo `tribuna`, scritto e provato). Migrazione 0003 **applicata da Claude** l'11/11 sera tramite token Supabase. Da unire su `main` dopo la prova di Flavio
6d. [x] **Modulo, sposta/scambia, vice di squadra, cambio ruolo diretto con "decido io", panchina sul cellulare, copia link** (richiesti l'11/11 sera): migrazioni 0004-0006 applicate da Claude, in anteprima su anteprima.nemanca1.pages.dev
6e. [x] **Modulo con tre contatori, senza portiere, mostrato sul campo** (richiesto l'11/11 sera), in anteprima
6f. [x] **Formazione trascinando i cerchi** con ruolo e modulo automatici (richiesto l'11/11 sera), in anteprima
6g. [x] **Selettore a passi** squadra → ruolo → cerchio per spostare o chiamare giocatori; **cognome e iniziale** sotto i cerchi (richiesti l'11/11 sera), in anteprima
7. [x] **Pagina amministratore** `/admin` (ramo `tappa-2`): numeri, ultimi iscritti con email e badge "nuovi", prossime partite con annulla, campi con verifica/elimina. Accesso dal Profilo, solo per `profili.admin` (il primo iscritto, Flavio)
8. [ ] **Avviso a Flavio a ogni nuovo iscritto** (richiesto l'11/11). Già fatto: badge "nuovi" nella pagina amministratore. Manca: email automatica (serve mettere la chiave Resend nei segreti di Supabase) e (trigger DB → Resend), poi come notifica push con OneSignal (Tappa 3) e lista "ultimi iscritti" nella pagina amministratore

9. [ ] **Entra con Google** (richiesto l'11/11, da fare per ultimo): login con un tocco accanto al codice via email; serve una configurazione OAuth su Google Cloud

10. [x] **Niente più copia-incolla SQL**: token Supabase (solo progetto nemanca1, permesso Database read-write, 90 giorni) salvato nell'ambiente cloud "nemanca1"; Claude applica le migrazioni con `scripts/applica-migrazione.sh`. Il collegamento GitHub-Supabase resta facoltativo.
    ~~Database automatico da GitHub~~ (richiesto l'11/11, da fare più avanti): collegare Supabase a GitHub, rinominare le migrazioni nel formato Supabase CLI e marcare 0001/0002 come già applicate

## Richieste di Flavio in sospeso

- **Da unire su www**: il sito vero ha la versione vecchia e mostra male le panchine (il database le contiene già). Serve il "unisci" di Flavio.

- **Sicurezza, per ultima** (deciso da Flavio l'11/11): revocare il primo token Supabase `claude-nemanca1` e rigenerare la chiave Resend, entrambi finiti in screenshot.

- ~~Mittente delle email automatiche~~ deciso: `benvenuto@nemanca1.com`; quando si crea la casella `info@`, aggiungere l'alias `benvenuto@` → `info@`
- ~~Backup del database~~ fatto: `scripts/backup.sh` scarica tutte le tabelle in CSV (serve la stringa di connessione dal bottone Connect di Supabase)
- **Pannello amministratore dentro l'app** (richiesto l'11/11): utenti, campi, partite, elimina/blocca, statistiche, accesso riservato a Flavio (flag `profili.admin`). Da fare dopo la Tappa 2. Nel frattempo si usa il pannello Supabase (Authentication → Users, Table Editor).

## Decisioni prese oggi

- Nome app "Ne manca 1", logo variante 5, slogan "Trova chi manca in campo"
- Email automatiche con Resend; Gmail, Tophost, Amazon SES e Lambda scartati (motivi in chat e in CLAUDE.md)
- Regione Supabase: Irlanda invece di Francoforte (non disponibile sul Free)
- Dominio: Tophost blocca i nameserver → DNS resta su Tophost, app su **www.nemanca1.com**, redirect dal dominio nudo. Flavio ha deciso di **non trasferire** il dominio: www è definitivo. Fonti: [record NS non modificabili](https://www.tophost.it/assistenza/supporto/domande-tecniche/dns/e-possibile-modificare-i-record-dns-del-dominio-ed-i-record-ns/), [Cloudflare con Tophost](https://www.tophost.it/assistenza/supporto/domande-tecniche/dns/posso-usare-cloudflare-con-tophost/)
