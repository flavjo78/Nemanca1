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

1. [x] **Nome senza www** (13/11: Remove + Save del dominio su GitHub → DNS verde, **certificato Let's Encrypt attivo**, **Enforce HTTPS** spuntato: http e https di nemanca1.com portano su www con il lucchetto, conservando percorso e parametri): repository `flavjo78/nemanca1-redirect` creato e caricato, GitHub Pages attivo con dominio `nemanca1.com`, 4 record `A` di `@` su Tophost verso GitHub (185.199.108-111.153), AAAA tolto. DNS già propagato l'11/11 sera. **Manca**: il controllo DNS di GitHub resta rosso finché scade la memoria del vecchio indirizzo (TTL Tophost 6 ore). 12/11 ore 9: DNS corretti (solo i 4 indirizzi GitHub), sito http attivo, certificato "1 of 3" in preparazione ma controllo DNS di GitHub ancora rosso e https non ancora valido. Se resta fermo: Remove e di nuovo Save del dominio su GitHub Pages. Poi: GitHub → Settings → Pages "Check again", poi spuntare **Enforce HTTPS**; Claude verifica che https://nemanca1.com porti su www con certificato valido
2. [x] **`supporto@nemanca1.com`** creato l'11/11 sera su Tophost (Email → Gestione avanzata) come **inoltro esterno** alla Gmail di Flavio. Tophost ha una sola MAILBOX (`nemanca1.com`, indirizzi di base webmaster@ e postmaster@); `info@` eliminato su richiesta di Flavio. Niente alias da `benvenuto@`
3. [x] **Tappa 3 – Chat** della partita in tempo reale (giocatori, organizzatore, vice, tribuna e chi ha un invito): elenco chat con pallino "nuovo", bolle, messaggi di sistema, card Accetta/Rifiuta per candidature e cambi ruolo, avviso invito. Migrazione 0009 applicata. Voce "Aiuto e supporto" nel Profilo e nel login. In anteprima
4. [x] **Autonomia via git** (13/11): **controlli automatici su GitHub** a ogni pubblicazione su anteprima e main (l'app si costruisce e tutte le schermate si aprono senza errori; tutte le migrazioni funzionano su un database vuoto e sono rieseguibili), primo giro verde; prove ripetibili anche in locale (`npm run prova`, `npm run prova:db`); l'ambiente cloud installa da solo le librerie a ogni nuova sessione. Migrazioni applicate da Claude dopo la prova, senza copia-incolla; su www solo dopo "unisci" e con controlli verdi
5. [x] **Tappa 3 – Notifiche push** (OneSignal) e **avviso a Flavio a ogni nuovo iscritto** (prima via email, poi push). 11/11: account OneSignal creato (piano Free, sito https://www.nemanca1.com, App ID 27506aa7-d2ae-4a62-8a47-56dad6193dd6, slide prompt in italiano senza avvio automatico, clic su notifica = stessa scheda). Fatto nell'app: file `OneSignalSDKWorker.js`, scheda **Notifiche** nel Profilo (Attiva/Spegni, istruzioni per iPhone), riquadro proposto dopo candidatura o ingresso in squadra, dispositivo collegato all'utente. 13/11: **notifiche attive di default** (riquadro "Attiva" proposto all'apertura a chi non ha deciso, ogni 3 giorni se dice "Più tardi"; alla prima iscrizione il "Continua" chiede subito il permesso; si spengono dal Profilo) e **invio automatico pronto nel database** (migrazione 0018: candidatura, accettata/rifiutata, invito, cambio ruolo, messaggi max 1 ogni 3 minuti per partita, nuovo iscritto agli amministratori). 13/11: chiave REST creata su OneSignal (nome `supabase`, senza IP allowlist) e salvata da Flavio nel Vault (`onesignal_rest_key`); prova riuscita sull'account giocatore su www. Le notifiche automatiche sono attive. Da unire su www: proposta automatica e richiesta alla prima iscrizione; prima: invio automatico dal database (accettato, invito, messaggio, cambio ruolo, nuovo iscritto a Flavio). Le notifiche funzionano solo su www, non sull'anteprima
6. [ ] **Tappa 4 – Social** (piano approvato da Flavio il 12/11), in quest'ordine:
   1. [~] **Raggio personalizzabile** (cursore 1-100 km + scorciatoie 5/10/20/30/50, migrazione 0019): su richiesta di Flavio il 13/11 **non sta nel profilo** ma nel bottone "Entro X km" nella pagina **Campi** (sotto la ricerca) e in **Home** (partite vicine); si salva subito. **"Cercami per le partite"** è un interruttore in **Home** (spento finché il giocatore non lo accende). In anteprima. Restano: campi frequentati, disponibilità facoltativa
   2. [~] **Mappa dei campi** (13/11, in anteprima): pagina Campi con schede **Lista / Mappa** (scelta ricordata sul telefono); mappa OpenStreetMap con segnaposto verde per ogni campo e **arancio con il numero** per i campi con partite con posti liberi; cerchio del raggio scelto attorno al tuo comune; toccando un segnaposto: nome, indirizzo, distanza, partite aperte e bottone "Apri il campo" ("Organizza qui" quando si sceglie dove organizzare). La ricerca per nome filtra anche la mappa
   3. Giocatori vicini al campo della partita (filtri ruolo, campo, voto) e inviti con limiti anti-spam
   4. Compagni di gioco, preferiti con stella, chat 1-a-1 (solo chi ha giocato insieme o ha un invito), blocca
   5. "Serve un portiere vicino a te": avviso ai giocatori della zona e del ruolo (richiede le notifiche automatiche)
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

- ~~In anteprima~~ unito su www il 12/11 (richiesti il 12/11): **nome bloccato** dopo il primo salvataggio (lo può correggere solo l'amministratore; migrazione 0015 applicata) e bottone del posto libero **"Posizionati qui"** al posto di "Siediti come…"; **partite giocate e archivio** (un'ora dopo l'inizio la partita è "giocata": esce dagli elenchi aperti; dal giorno dopo va in archivio e solo allora la chat diventa di sola lettura (migrazione 0017); nulla si cancella: formazione, modulo, partecipanti, panchina, tribuna e chat restano; pagina Profilo → "Partite giocate e archivio"; migrazione 0016 applicata, aggiornamento automatico ogni 5 minuti con pg_cron)
- ~~In anteprima~~ unito il 12/11: **icona nera "Ne manca 1 Admin"** per l'app installata da https://nemanca1.pages.dev (account amministratore; il giocatore usa www con le notifiche). Dopo l'unione: disinstallare e reinstallare l'icona Admin
- ~~In anteprima, da unire dopo l'ok~~ unito l'11/11 notte: candidatura con preferenza di squadra, icona campetto nella chat, nome di chi si candida, termometro, cambio ruolo che sposta il giocatore, **in campo sempre i giocatori del formato** (calcio a 5 = portiere + 4: i contatori del modulo non superano il totale, si aggiungono/tolgono solo riserve in panchina; migrazione 0014 applicata)
- ~~Da unire su www~~ fatto l'11/11 sera: www.nemanca1.com ha tribuna, panchine, modulo, trascinamento, vice, selettore a passi, copia link.


- ~~Mittente delle email automatiche~~ deciso: `benvenuto@nemanca1.com`; quando si crea la casella `info@`, aggiungere l'alias `benvenuto@` → `info@`
- ~~Backup del database~~ fatto: `scripts/backup.sh` scarica tutte le tabelle in CSV (serve la stringa di connessione dal bottone Connect di Supabase)
- **Pannello amministratore dentro l'app** (richiesto l'11/11): utenti, campi, partite, elimina/blocca, statistiche, accesso riservato a Flavio (flag `profili.admin`). Da fare dopo la Tappa 2. Nel frattempo si usa il pannello Supabase (Authentication → Users, Table Editor).

## Decisioni prese oggi

- Nome app "Ne manca 1", logo variante 5, slogan "Trova chi manca in campo"
- Email automatiche con Resend; Gmail, Tophost, Amazon SES e Lambda scartati (motivi in chat e in CLAUDE.md)
- Regione Supabase: Irlanda invece di Francoforte (non disponibile sul Free)
- Dominio: Tophost blocca i nameserver → DNS resta su Tophost, app su **www.nemanca1.com**, redirect dal dominio nudo. Flavio ha deciso di **non trasferire** il dominio: www è definitivo. Fonti: [record NS non modificabili](https://www.tophost.it/assistenza/supporto/domande-tecniche/dns/e-possibile-modificare-i-record-dns-del-dominio-ed-i-record-ns/), [Cloudflare con Tophost](https://www.tophost.it/assistenza/supporto/domande-tecniche/dns/posso-usare-cloudflare-con-tophost/)
