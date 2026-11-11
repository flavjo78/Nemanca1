<!-- Mostrata quando manca il file .env: spiega cosa fare invece di una pagina bianca -->
<div class="pagina">
  <div class="intestazione-verde"><h1>Calcetto</h1><p class="sotto">Manca la configurazione di Supabase</p></div>
  <div class="contenuto spazio-sopra">
    <div class="card" style="gap:10px; font-size:14px">
      <p>L'app non trova <strong>VITE_SUPABASE_URL</strong> e <strong>VITE_SUPABASE_ANON_KEY</strong>.</p>
      <p>In locale: copia <code>.env.example</code> in <code>.env</code> e inserisci URL e chiave anon del progetto (Supabase → Project Settings → API).</p>
      <p>Su Cloudflare Pages: aggiungi le stesse variabili in Settings → Environment variables e rifai il deploy.</p>
    </div>
  </div>
</div>
