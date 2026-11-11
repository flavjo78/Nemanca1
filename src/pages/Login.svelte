<script>
  import { supabase } from '../lib/supabase.js'
  import { naviga, router } from '../lib/router.svelte.js'
  import Icona from '../components/Icona.svelte'

  let email = $state('')
  let codice = $state('')
  let fase = $state('email') // email | codice
  let errore = $state('')
  let occupato = $state(false)
  const destinazione = $derived(router.query.get('next') || '/')

  async function inviaCodice(e) {
    e.preventDefault()
    errore = ''
    occupato = true
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim().toLowerCase(),
      options: { shouldCreateUser: true }
    })
    occupato = false
    if (error) { errore = traduci(error.message); return }
    fase = 'codice'
  }

  async function verifica(e) {
    e.preventDefault()
    errore = ''
    occupato = true
    const { error } = await supabase.auth.verifyOtp({
      email: email.trim().toLowerCase(),
      token: codice.replace(/\s/g, ''),
      type: 'email'
    })
    occupato = false
    if (error) { errore = traduci(error.message); return }
    naviga(destinazione, { sostituisci: true })
  }

  function traduci(m = '') {
    if (/rate limit|too many/i.test(m)) return 'Troppi tentativi: aspetta un minuto e riprova.'
    if (/expired|invalid/i.test(m)) return 'Codice non valido o scaduto. Richiedine uno nuovo.'
    if (/invalid.*email|valid email/i.test(m)) return 'Controlla l\'indirizzo email.'
    return m || 'Qualcosa non ha funzionato. Riprova.'
  }
</script>

<div class="pagina">
  <div class="intestazione-verde" style="padding-bottom: 32px; border-radius: 0 0 28px 28px">
    <div style="display:flex; align-items:center; gap:12px">
      <img src="/icona.svg" alt="" width="44" height="44" style="border-radius:12px" />
      <h1 style="font-size: 26px">Ne manca 1</h1>
    </div>
    <p class="sotto">Trova giocatori per le partite nei campi vicino a te.</p>
  </div>

  <div class="contenuto spazio-sopra">
    {#if fase === 'email'}
      <form class="sezione" onsubmit={inviaCodice} style="gap: 14px">
        <div class="sezione-titolo">Entra con la tua email</div>
        <div class="campo-form">
          <label for="email">Email</label>
          <input id="email" class="input" type="email" inputmode="email" autocomplete="email" required bind:value={email} placeholder="nome@esempio.it" />
        </div>
        <p class="aiuto">Ti mandiamo un codice di 6 cifre. Niente password da ricordare.</p>
        {#if errore}<div class="errore">{errore}</div>{/if}
        <button class="btn" type="submit" disabled={occupato}>
          <Icona nome="mail" dimensione={18} spessore={2.2} />
          {occupato ? 'Invio in corso…' : 'Mandami il codice'}
        </button>
      </form>
    {:else}
      <form class="sezione" onsubmit={verifica} style="gap: 14px">
        <div class="sezione-titolo">Inserisci il codice</div>
        <p class="aiuto">Abbiamo mandato un codice a <strong>{email}</strong>. Controlla anche la posta indesiderata.</p>
        <div class="campo-form">
          <label for="codice">Codice a 6 cifre</label>
          <input id="codice" class="input codice" type="text" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9 ]*" maxlength="8" required bind:value={codice} />
        </div>
        {#if errore}<div class="errore">{errore}</div>{/if}
        <button class="btn" type="submit" disabled={occupato || codice.replace(/\s/g, '').length < 6}>
          {occupato ? 'Verifica…' : 'Entra'}
        </button>
        <button class="btn bianco" type="button" onclick={() => { fase = 'email'; codice = ''; errore = '' }}>Cambia email o richiedi un nuovo codice</button>
      </form>
    {/if}
    <a href={destinazione.startsWith('/campo/') ? destinazione : '/campi'} class="aiuto" style="text-align:center">Continua senza accedere: guarda i campi</a>
  </div>
</div>
