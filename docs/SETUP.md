# Configurazione: Supabase, Resend, Cloudflare Pages

## 1. Supabase

1. Crea un progetto su supabase.com, regione **eu-central-1 (Francoforte)**.
2. Apri **SQL Editor → New query**, incolla tutto `supabase/migrations/0001_schema.sql` ed esegui.
3. **Authentication → Providers → Email**: lascia attivo Email, disattiva "Confirm email" se vuoi evitare il doppio passaggio, e imposta la lunghezza OTP a 6.
4. **Authentication → Email Templates → Magic Link**: il corpo deve contenere il codice, non il link. Esempio:

   ```html
   <h2>Il tuo codice per Calcetto</h2>
   <p>Inserisci questo codice nell'app: <strong>{{ .Token }}</strong></p>
   <p>Scade tra un'ora. Se non l'hai richiesto, ignora questa email.</p>
   ```

5. **Authentication → URL Configuration**: Site URL = l'indirizzo dell'app (es. `https://calcetto.tuodominio.it`); aggiungi anche `http://localhost:5173` ai Redirect URLs.
6. **Project Settings → API**: copia `Project URL` e `anon public key` nel file `.env`:

   ```
   VITE_SUPABASE_URL=https://xxxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJ...
   ```

Il piano gratuito limita le email di autenticazione inviate da Supabase a poche all'ora: per i test con più persone serve lo SMTP di Resend (punto 2).

## 2. Resend (email automatiche)

1. Crea un account su resend.com, aggiungi il dominio e inserisci i record **SPF e DKIM** nel DNS su Cloudflare (la casella `info@` su Tophost continua a funzionare).
2. Crea una API key.
3. In Supabase, **Project Settings → Authentication → SMTP Settings**: attiva Custom SMTP con
   - Host `smtp.resend.com`, porta `465`
   - Username `resend`, password = la API key
   - Sender `noreply@tuodominio.it`, nome `Calcetto`

## 3. GitHub e Cloudflare Pages

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
4. Dominio: aggiungi il sottodominio nel pannello Pages → Custom domains (il DNS è già su Cloudflare).

## 4. Prova sul telefono

1. Apri l'app, entra con la tua email e inserisci il codice.
2. Completa il profilo con nome e comune.
3. Registra un campo (puoi usare la posizione del telefono), stampa il QR.
4. Crea una partita su quel campo e inquadra il QR con un altro telefono: si apre `/campo/<id>` senza login.
