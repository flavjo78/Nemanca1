# I servizi che usiamo e come si parlano

Aggiornato l'11 novembre 2026.

| Servizio | A cosa serve | Dove si entra | Cosa c'è di nostro |
|---|---|---|---|
| **GitHub** | Cassaforte del codice, storia delle versioni | github.com, account flavjo78 | repository `Nemanca1` |
| **Cloudflare Pages** | Pubblica l'app su internet; si aggiorna da solo a ogni modifica su GitHub | dash.cloudflare.com → Compute → Workers & Pages | progetto `nemanca1`, dominio `www.nemanca1.com` |
| **Supabase** | Database, login con codice, regole di sicurezza. È anche il pannello di controllo (utenti, tabelle) | supabase.com → progetto `nemanca1` (Irlanda) | tabelle, template email, SMTP, chiavi |
| **Resend** | Spedisce le email automatiche per conto dell'app | resend.com | dominio `nemanca1.com` verificato, API key usata da Supabase |
| **Tophost** | Proprietà del dominio, elenco DNS, casella email `info@` | cp.tophost.it | dominio `nemanca1.com` (TopName), record DNS |
| **OneSignal** (in futuro) | Notifiche push sul telefono | onesignal.com | ancora da creare |

## Il flusso di un login

1. L'utente apre `www.nemanca1.com` (Cloudflare Pages), scrive l'email e tocca "Mandami il codice".
2. L'app chiede a **Supabase** di generare il codice. Supabase lo salva e prepara l'email con il template.
3. Supabase consegna l'email a **Resend** (SMTP) con mittente `benvenuto@nemanca1.com`.
4. **Resend** firma (DKIM) e spedisce. Il destinatario verifica nel DNS di **Tophost** che Resend sia autorizzato (SPF/DKIM) e la consegna in posta in arrivo.
5. L'utente inserisce il codice, Supabase lo verifica, l'app lo fa entrare e crea il profilo.

## Mittenti delle email

- `benvenuto@nemanca1.com`: codice di accesso (unico mittente possibile per Supabase Auth).
- `avvisi@nemanca1.com` (proposto): notifiche future ("serve un portiere", "sei stato accettato"), inviate dal codice dell'app tramite Resend.
- Le caselle servono solo per ricevere: `info@nemanca1.com` su Tophost, con alias `benvenuto@` e `avvisi@` → `info@` per non perdere le risposte.

## Chi costa quanto (oggi)

Tutto gratuito tranne il dominio su Tophost (pochi euro l'anno). Supabase Pro (25 $/mese) solo quando servirà più spazio o backup giornalieri.
