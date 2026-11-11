# Il punto della situazione – Ne manca 1

Aggiornato: 11 novembre 2026, pomeriggio. Questo file si aggiorna a ogni passaggio e si ripropone a Flavio.

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

## In corso

- [ ] **Prova del login**: codice inviato alla Gmail di Flavio, in attesa del codice per completare la verifica

## Da fare, in ordine

1. [ ] **Cloudflare Pages**: collegare GitHub, pubblicare l'app su un indirizzo `.pages.dev`, mettere le due variabili di Supabase
2. [ ] Supabase → URL Configuration: mettere l'indirizzo dell'app pubblicata
3. [ ] Prima prova dal telefono: login, profilo, registrare un campo, stampare il QR, creare una partita
4. [ ] **Dominio**: nameserver di nemanca1.com da Tophost a Cloudflare (prima copiare i record della posta)
5. [ ] Casella `info@nemanca1.com` e alias su Tophost
6. [ ] **Resend**: verificare il dominio (SPF + DKIM su Cloudflare), mittente `noreply@nemanca1.com`, rigenerare la API key e cancellare quella mostrata in chat
7. [ ] Cloudflare Pages: agganciare nemanca1.com e www
8. [ ] Tappa 2: prendere un posto libero, candidarsi, accettare, cambio ruolo

## Richieste di Flavio in sospeso

- (nessuna)

## Decisioni prese oggi

- Nome app "Ne manca 1", logo variante 5, slogan "Trova chi manca in campo"
- Email automatiche con Resend; Gmail, Tophost, Amazon SES e Lambda scartati (motivi in chat e in CLAUDE.md)
- Regione Supabase: Irlanda invece di Francoforte (non disponibile sul Free)
