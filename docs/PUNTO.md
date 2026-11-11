# Il punto della situazione – Ne manca 1

Aggiornato: 11 novembre 2026, sera: le email arrivano a chiunque. Questo file si aggiorna a ogni passaggio e si ripropone a Flavio.

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
- [x] Supabase → URL Configuration: Site URL `https://www.nemanca1.com`, Redirect URLs www e pages.dev
- [x] **Login provato per davvero**: email arrivata via Resend, codice (8 cifre) accettato, profilo creato in automatico

## In corso

- [ ] Prima prova dal telefono di Flavio (con flavjo@gmail.com: unico indirizzo che riceve finché Resend non ha il dominio)
- [ ] **Dominio, piano B** (Tophost non permette di cambiare i nameserver):
  1. ~~Tophost DNS: CNAME `www`~~ fatto
  2. ~~Cloudflare Pages → Custom domains → `www.nemanca1.com`~~ fatto
  3. Tophost → Redirect dominio: `nemanca1.com` → `https://www.nemanca1.com`
  4. ~~Resend → Domains → `nemanca1.com`~~ fatto

## Da fare, in ordine

1. [ ] Supabase → URL Configuration: mettere l'indirizzo dell'app pubblicata
3. [ ] Prima prova dal telefono: login, profilo, registrare un campo, stampare il QR, creare una partita
2. [ ] Cloudflare: cancellare la zona `nemanca1.com` rimasta "pending" (o tenerla per il trasferimento)
3. [ ] Casella `info@nemanca1.com` e alias su Tophost
4. [ ] **Resend**: verificare il dominio (SPF + DKIM su Cloudflare), mittente `noreply@nemanca1.com`, rigenerare la API key e cancellare quella mostrata in chat
6. [ ] Tappa 2: prendere un posto libero, candidarsi, accettare, cambio ruolo
7. [ ] **Pagina amministratore** per Flavio dentro l'app: utenti attivi, partite, campi, blocca/elimina, statistiche
8. [ ] **Avviso a Flavio a ogni nuovo iscritto** (richiesto l'11/11): prima via email (trigger DB → Resend), poi come notifica push con OneSignal (Tappa 3) e lista "ultimi iscritti" nella pagina amministratore

9. [ ] **Entra con Google** (richiesto l'11/11, da fare per ultimo): login con un tocco accanto al codice via email; serve una configurazione OAuth su Google Cloud

## Richieste di Flavio in sospeso

- ~~Mittente delle email automatiche~~ deciso: `benvenuto@nemanca1.com`; quando si crea la casella `info@`, aggiungere l'alias `benvenuto@` → `info@`
- **Backup del database** (richiesto l'11/11): script per scaricare tutte le tabelle Supabase in locale, da lanciare a piacere (il piano Free non ha backup automatici)
- **Pannello amministratore dentro l'app** (richiesto l'11/11): utenti, campi, partite, elimina/blocca, statistiche, accesso riservato a Flavio (flag `profili.admin`). Da fare dopo la Tappa 2. Nel frattempo si usa il pannello Supabase (Authentication → Users, Table Editor).

## Decisioni prese oggi

- Nome app "Ne manca 1", logo variante 5, slogan "Trova chi manca in campo"
- Email automatiche con Resend; Gmail, Tophost, Amazon SES e Lambda scartati (motivi in chat e in CLAUDE.md)
- Regione Supabase: Irlanda invece di Francoforte (non disponibile sul Free)
- Dominio: Tophost blocca i nameserver → DNS resta su Tophost, app su **www.nemanca1.com**, redirect dal dominio nudo. Flavio ha deciso di **non trasferire** il dominio: www è definitivo. Fonti: [record NS non modificabili](https://www.tophost.it/assistenza/supporto/domande-tecniche/dns/e-possibile-modificare-i-record-dns-del-dominio-ed-i-record-ns/), [Cloudflare con Tophost](https://www.tophost.it/assistenza/supporto/domande-tecniche/dns/posso-usare-cloudflare-con-tophost/)
