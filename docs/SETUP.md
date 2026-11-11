# Configurazione: Supabase, Resend, Cloudflare Pages

## 1. Supabase

1. Crea un progetto su supabase.com, regione **eu-central-1 (Francoforte)**.
2. Apri **SQL Editor → New query**, incolla tutto `supabase/migrations/0001_schema.sql` ed esegui.
3. **Attenzione**: senza un SMTP personalizzato Supabase non permette di modificare i template email, e il template di default manda un link, non il codice. Quindi prima configura Resend (sezione 3) in **Authentication → Emails → SMTP Settings**.
4. **Authentication → Emails → Templates**: sia in "Confirm sign up" sia in "Magic link or OTP" il corpo deve contenere il codice, non il link:

   ```html
   <h2>Il tuo codice per Ne manca 1</h2>
   <p>Inserisci questo codice nell'app: <strong>{{ .Token }}</strong></p>
   <p>Scade tra un'ora. Se non l'hai richiesto, ignora questa email.</p>
   ```

5. **Authentication → URL Configuration**: Site URL = `https://www.nemanca1.com` (aggiungi ai Redirect URLs anche `https://nemanca1.pages.dev/**`); aggiungi anche `http://localhost:5173` ai Redirect URLs.
6. **Project Settings → API**: copia `Project URL` e `anon public key` nel file `.env`:

   ```
   VITE_SUPABASE_URL=https://xxxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJ...
   ```

Il piano gratuito limita le email di autenticazione inviate da Supabase a poche all'ora: per i test con più persone serve lo SMTP di Resend (punto 2).

## 2. Dominio nemanca1.com

Il dominio è **nemanca1.com**, comprato su Tophost (TopName). **Tophost non permette di cambiare i nameserver**, quindi il DNS resta nel pannello Tophost (Utility → Gestione DNS) e le righe si aggiungono lì a mano.

1. **App su www**: su Tophost togli i record A/AAAA di `www` e aggiungi `CNAME www → nemanca1.pages.dev`. Su Cloudflare Pages → progetto → Custom domains → `www.nemanca1.com` → "My DNS provider" → Check DNS records. Fatto l'11/11/2026: `https://www.nemanca1.com` risponde con HTTPS.
2. **Dominio nudo**: Tophost → Utility → Redirect dominio: `nemanca1.com` → `https://www.nemanca1.com`.
3. **Posta**: i record MX di Tophost restano com'erano; la casella `info@` si crea da Tophost → Email.
4. Tra 60 giorni dalla registrazione si può trasferire il dominio a Cloudflare Registrar: a quel punto il DNS passa a Cloudflare e anche `nemanca1.com` senza www può puntare all'app.

## 3. Resend (email automatiche)

1. Su resend.com → Domains → aggiungi `nemanca1.com` (regione Europe) e inserisci i record **DKIM e SPF** che ti dà nel pannello DNS di **Tophost** (la casella `info@` continua a funzionare, Resend invia solo da `benvenuto@`).
2. Crea una API key.
3. In Supabase, **Project Settings → Authentication → SMTP Settings**: attiva Custom SMTP con
   - Host `smtp.resend.com`, porta `465`
   - Username `resend`, password = la API key
   - Sender `benvenuto@nemanca1.com`, nome `Ne manca 1`. Finché il dominio non è verificato su Resend usa `onboarding@resend.dev`: le email arrivano solo all'indirizzo dell'account Resend.

## 4. GitHub e Cloudflare Pages

1. Crea il repository su GitHub (es. `calcetto-app`) e carica il progetto:

   ```bash
   git remote add origin https://github.com/<utente>/calcetto-app.git
   git push -u origin main
   ```

2. Su Cloudflare: **Workers & Pages → Create → Pages → Connect to Git**, scegli il repo.
   - Framework preset: **Vite** (o None)
   - Build command: `npm run build`
   - Build output directory: `dist`
   - Environment variables: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` (anche per Preview)
3. Ogni push su `main` rifà il deploy. Il file `public/_redirects` fa funzionare i link diretti tipo `/campo/<id>`.
4. Dominio: vedi sezione 2 (solo `www.nemanca1.com`, con CNAME su Tophost).

## 5. Prova sul telefono

1. Apri l'app, entra con la tua email e inserisci il codice.
2. Completa il profilo con nome e comune.
3. Registra un campo (puoi usare la posizione del telefono), stampa il QR.
4. Crea una partita su quel campo e inquadra il QR con un altro telefono: si apre `/campo/<id>` senza login.
