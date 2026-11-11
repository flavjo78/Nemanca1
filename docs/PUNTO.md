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

1. [~] **Nome senza www**: repository `flavjo78/nemanca1-redirect` creato e caricato, GitHub Pages attivo con dominio `nemanca1.com`, 4 record `A` di `@` su Tophost verso GitHub (185.199.108-111.153), AAAA tolto. DNS già propagato l'11/11 sera. **Manca**: il controllo DNS di GitHub resta rosso finché scade la memoria del vecchio indirizzo (TTL Tophost 6 ore). Il 12/11: GitHub → Settings → Pages "Check again", poi spuntare **Enforce HTTPS**; Claude verifica che https://nemanca1.com porti su www con certificato valido
2. [x] **`supporto@nemanca1.com`** creato l'11/11 sera su Tophost (Email → Gestione avanzata) come **inoltro esterno** alla Gmail di Flavio. Tophost ha una sola MAILBOX (`nemanca1.com`, indirizzi di base webmaster@ e postmaster@); `info@` eliminato su richiesta di Flavio. Niente alias da `benvenuto@`
3. [x] **Tappa 3 – Chat** della partita in tempo reale (giocatori, organizzatore, vice, tribuna e chi ha un invito): elenco chat con pallino "nuovo", bolle, messaggi di sistema, card Accetta/Rifiuta per candidature e cambi ruolo, avviso invito. Migrazione 0009 applicata. Voce "Aiuto e supporto" nel Profilo e nel login. In anteprima
4. [ ] **Autonomia via git** (richiesto l'11/11, subito dopo la chat): Claude fa tutte le modifiche da solo, senza copia-incolla di Flavio. Comprende: collegamento Supabase-GitHub per applicare le migrazioni a ogni unione su `main`; regola di permesso in Claude Code per pubblicare su `main` dopo il "unisci" senza blocchi; controlli automatici (build + test) su GitHub prima di ogni pubblicazione; nessun passaggio che chieda a Flavio di copiare codice o testo
5. [~] **Tappa 3 – Notifiche push** (OneSignal) e **avviso a Flavio a ogni nuovo iscritto** (prima via email, poi push). 11/11: Flavio sta creando l'account OneSignal (canale Push, sito Web https://www.nemanca1.com); poi App ID (pubblico) e chiave REST tramite modulo sicuro
6. [ ] **Tappa 4 – Social**: lista amici, giocatori vicini, inviti, mappa campi
7. [ ] **Tappa 5 – Dopo la partita**: risultato, recensioni anonime, voti, storico
8. [ ] **Tappa 6**: PWA installabile completa, QR stampabili, prova con 10 persone su un campo vero
9. [ ] **Entra con Google**
10. [ ] *Facoltativo*: filtro in Gmail (dal computer) per le email a `supporto@nemanca1.com`: etichetta "Ne manca 1", "Non inviare mai in Spam", eventualmente "importante"
    [x] **Termometro dello spazio** nella pagina amministratore (richiesto l'11/11): barra su 500 MB, verde/gialla 60%/rossa 80%, peso di chat, partite, utenti
    [ ] **Scarica archivio** dalla pagina amministratore (richiesto l'11/11): chat, partite, utenti in un file da conservare prima della pulizia
    [ ] **Passare a Supabase Pro** quando arrivano utenti regolari (più connessioni in tempo reale, niente pausa per inattività, backup giornalieri)
    [ ] *Facoltativo*: pulizia automatica delle chat di partite vecchie (es. oltre 6 mesi), se il database si avvicina ai 500 MB del piano gratuito (l'11/11: 12 MB in tutto, 48 kB di messaggi)
    [ ] *Facoltativo, alla fine*: in Gmail "Invia come supporto@nemanca1.com" (SMTP di Tophost), per rispondere agli utenti dall'indirizzo del supporto
11. [ ] **Sicurezza, per ultima**: revocare il primo token Supabase e rigenerare la chiave Resend (finiti in screenshot)

## Richieste di Flavio in sospeso

- *Facoltativo*: **copia delle email di supporto@ anche su Tophost**. Provato l'11/11: Tophost non accetta una seconda destinazione per lo stesso indirizzo ("già esistente"). Se servirà, ticket all'assistenza Tophost; intanto supporto@ arriva solo alla Gmail

- In anteprima, da unire dopo l'ok: candidatura con preferenza di squadra, icona campetto nella chat, nome di chi si candida, termometro, cambio ruolo che sposta il giocatore, **in campo sempre i giocatori del formato** (calcio a 5 = portiere + 4: i contatori del modulo non superano il totale, si aggiungono/tolgono solo riserve in panchina; migrazione 0014 applicata)
- ~~Da unire su www~~ fatto l'11/11 sera: www.nemanca1.com ha tribuna, panchine, modulo, trascinamento, vice, selettore a passi, copia link.


- ~~Mittente delle email automatiche~~ deciso: `benvenuto@nemanca1.com`; quando si crea la casella `info@`, aggiungere l'alias `benvenuto@` → `info@`
- ~~Backup del database~~ fatto: `scripts/backup.sh` scarica tutte le tabelle in CSV (serve la stringa di connessione dal bottone Connect di Supabase)
- **Pannello amministratore dentro l'app** (richiesto l'11/11): utenti, campi, partite, elimina/blocca, statistiche, accesso riservato a Flavio (flag `profili.admin`). Da fare dopo la Tappa 2. Nel frattempo si usa il pannello Supabase (Authentication → Users, Table Editor).

## Decisioni prese oggi

- Nome app "Ne manca 1", logo variante 5, slogan "Trova chi manca in campo"
- Email automatiche con Resend; Gmail, Tophost, Amazon SES e Lambda scartati (motivi in chat e in CLAUDE.md)
- Regione Supabase: Irlanda invece di Francoforte (non disponibile sul Free)
- Dominio: Tophost blocca i nameserver → DNS resta su Tophost, app su **www.nemanca1.com**, redirect dal dominio nudo. Flavio ha deciso di **non trasferire** il dominio: www è definitivo. Fonti: [record NS non modificabili](https://www.tophost.it/assistenza/supporto/domande-tecniche/dns/e-possibile-modificare-i-record-dns-del-dominio-ed-i-record-ns/), [Cloudflare con Tophost](https://www.tophost.it/assistenza/supporto/domande-tecniche/dns/posso-usare-cloudflare-con-tophost/)
