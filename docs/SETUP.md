# Configurazione: Supabase, Resend, Cloudflare Pages

## 1. Supabase

1. Crea un progetto su supabase.com, regione **eu-central-1 (Francoforte)**.
2. Apri **SQL Editor → New query**, incolla tutto `supabase/migrations/0001_schema.sql` ed esegui.
3. **Authentication → Providers → Email**: lascia attivo Email, disattiva "Confirm email" se vuoi evitare il doppio passaggio, e imposta la lunghezza OTP a 6.
4. **Authentication → Email Templates → Magic Link**: il corpo deve contenere il codice, non il link. Esempio:

   ```html
   <h2>Il tuo codice per Ne manca 1</h2>
   <p>Inserisci questo codice nell'app: <strong>{{ .Token }}</strong></p>
   <p>Scade tra un'ora. Se non l'hai richiesto, ignora questa email.</p>
   ```

5. **Authentication → URL Configuration**: Site URL = `https://nemanca1.com`; aggiungi anche `http://localhost:5173` ai Redirect URLs.
6. **Project Settings → API**: copia `Project URL` e `anon public key` nel file `.env`:

   ```
   VITE_SUPABASE_URL=https://xxxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJ...
   ```

Il piano gratuito limita le email di autenticazione inviate da Supabase a poche all'ora: per i test con più persone serve lo SMTP di Resend (punto 2).

## 2. Dominio nemanca1.com

Il dominio è **nemanca1.com**. L'app risponde su `https://nemanca1.com` (e `www`), così il QR dei campi è corto: `nemanca1.com/campo/<id>`.

1. Su Cloudflare: **Add a site → nemanca1.com**, piano Free. Cloudflare mostra due nameserver.
2. Nel pannello dove hai comprato il dominio, sostituisci i nameserver con quelli di Cloudflare (se l'hai comprato su Cloudflare è già fatto). La propagazione richiede da pochi minuti a 24 ore.
3. Se le caselle email (`info@nemanca1.com`) stanno su Tophost, prima del cambio copia su Cloudflare i record **MX** e il record SPF esistente: altrimenti la posta si ferma.

## 3. Resend (email automatiche)

1. Crea un account su resend.com, aggiungi il dominio `nemanca1.com` e inserisci i record **SPF e DKIM** che ti dà nel DNS su Cloudflare (la casella `info@` continua a funzionare, Resend invia solo da `noreply@`).
2. Crea una API key.
3. In Supabase, **Project Settings → Authentication → SMTP Settings**: attiva Custom SMTP con
   - Host `smtp.resend.com`, porta `465`
   - Username `resend`, password = la API key
   - Sender `noreply@nemanca1.com`, nome `Ne manca 1`

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
4. Dominio: in Pages → **Custom domains** aggiungi `nemanca1.com` e `www.nemanca1.com`; Cloudflare crea da solo i record DNS e il certificato.

## 5. Prova sul telefono

1. Apri l'app, entra con la tua email e inserisci il codice.
2. Completa il profilo con nome e comune.
3. Registra un campo (puoi usare la posizione del telefono), stampa il QR.
4. Crea una partita su quel campo e inquadra il QR con un altro telefono: si apre `/campo/<id>` senza login.
