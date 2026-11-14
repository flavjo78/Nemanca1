<script>
  // Primo accesso: nome e comune (serve per "partite vicino a te")
  import { supabase } from '../lib/supabase.js'
  import { auth, caricaProfilo } from '../lib/auth.svelte.js'
  import ScegliComune from '../components/ScegliComune.svelte'
  import { naviga, router } from '../lib/router.svelte.js'
  import { RUOLI } from '../lib/formato.js'
  import { notifiche, attivaNotifiche } from '../lib/notifiche.svelte.js'
  import { caricaFoto, togliFoto } from '../lib/foto.js'
  import Avatar from '../components/Avatar.svelte'

  let fotoOccupato = $state(false)
  let fotoMessaggio = $state('')
  async function sceltaFoto(e) {
    const file = e.currentTarget.files?.[0]
    e.currentTarget.value = ''
    if (!file) return
    fotoOccupato = true; fotoMessaggio = ''
    try {
      const { peso } = await caricaFoto(file)
      fotoMessaggio = `Foto salvata (${Math.max(1, Math.round(peso / 1024))} KB).`
    } catch (err) {
      fotoMessaggio = /formato/.test(err?.message) ? 'Questo file non è una foto che riesco a leggere. Prova con un\'altra.' : 'Non sono riuscito a caricare la foto. Riprova.'
    } finally { fotoOccupato = false }
  }
  async function rimuoviFoto() {
    fotoOccupato = true; fotoMessaggio = ''
    try { await togliFoto(); fotoMessaggio = 'Foto tolta.' } catch { fotoMessaggio = 'Non sono riuscito a togliere la foto.' } finally { fotoOccupato = false }
  }

  let nome = $state(auth.profilo?.nome ?? '')
  // il nome si sceglie una volta sola (lo blocca anche il database)
  const nomeBloccato = !!auth.profilo?.nome?.trim()
  let comuneScelto = $state(auth.profilo?.comune ? { comune: auth.profilo.comune, lat: auth.profilo.lat, lng: auth.profilo.lng } : null)
  let campoComune = $state(null)
  let ruoli = $state([...(auth.profilo?.ruoli_preferiti ?? [])])
  let errore = $state('')
  let occupato = $state(false)
  function alternaRuolo(r) { ruoli = ruoli.includes(r) ? ruoli.filter((x) => x !== r) : [...ruoli, r] }

  async function salva(e) {
    e.preventDefault()
    errore = ''
    if (nome.trim().length < 2) { errore = 'Scrivi il tuo nome.'; return }
    // nuovo iscritto: notifiche attive di default, il browser chiede subito il suo "Consenti"
    if (!nomeBloccato && notifiche.stato === 'spente' && window.Notification?.permission === 'default') attivaNotifiche().catch(() => {})
    occupato = true
    const dati = { id: auth.utente.id, ruoli_preferiti: ruoli }
    if (!nomeBloccato) dati.nome = nome.trim()
    // il comune si chiede solo alla prima iscrizione (dopo si cambia da Campi o Home: "da …")
    if (!nomeBloccato) {
      const c = await campoComune?.conferma()
      if (c) { dati.comune = c.comune; dati.lat = c.lat; dati.lng = c.lng }
    }
    const { error } = await supabase.from('profili').upsert(dati)
    occupato = false
    if (error) { errore = error.message; return }
    await caricaProfilo()
    // dal link di una partita o di un campo si resta lì; solo dalla modifica profilo si torna al profilo
    if (router.percorso === '/profilo/modifica') naviga('/profilo', { sostituisci: true })
  }
</script>

<div class="pagina">
  <div class="intestazione">
    <div class="centro">
      <h1 style="font-size: 26px">{nomeBloccato ? 'Il tuo profilo' : 'Come ti chiami?'}</h1>
      <div class="sotto">Gli altri giocatori vedranno il tuo nome e la tua foto.</div>
    </div>
  </div>
  <form class="contenuto" onsubmit={salva}>
    {#if auth.utente}
      <div class="campo-form foto-riga">
        <Avatar profilo={{ ...auth.profilo, nome: nome || auth.profilo?.nome }} dimensione={72} classe="verde" />
        <div class="riempi" style="display:flex; flex-direction:column; gap:6px">
          <label class="btn bianco piccolo" style="cursor:pointer; width:auto" aria-disabled={fotoOccupato}>
            {fotoOccupato ? 'Sto preparando la foto…' : auth.profilo?.foto_url ? 'Cambia foto' : 'Aggiungi una foto'}
            <input type="file" accept="image/*,.heic,.heif" onchange={sceltaFoto} disabled={fotoOccupato} hidden />
          </label>
          {#if auth.profilo?.foto_url}<button type="button" class="link-piccolo" disabled={fotoOccupato} onclick={rimuoviFoto}>Togli la foto</button>{/if}
        </div>
      </div>
      <p class="aiuto">{fotoMessaggio || 'Scatta una foto o scegline una: la riduciamo noi, pesa pochissimo.'}</p>
    {/if}
    <div class="campo-form">
      <label for="nome">Nome e cognome</label>
      <input id="nome" class="input" type="text" autocomplete="name" required bind:value={nome} placeholder="Marco Rizzo" readonly={nomeBloccato} style={nomeBloccato ? 'background: var(--neutro); color: var(--testo-2)' : ''} />
      <p class="aiuto">{nomeBloccato ? 'Il nome non si può cambiare. Se è sbagliato scrivi a supporto@nemanca1.com.' : 'Scrivi nome e cognome veri: dopo non si potranno più cambiare.'}</p>
    </div>
    {#if !nomeBloccato}
      <ScegliComune bind:this={campoComune} bind:scelto={comuneScelto} aiuto="Serve per mostrarti le partite e i campi vicini. Potrai cambiarlo dalla pagina Campi." />
    {/if}
    <div class="campo-form">
      <span class="aiuto" style="font-weight:600">Dove giochi di solito?</span>
      <div class="scelte">
        {#each Object.entries(RUOLI) as [chiave, testo]}
          <button type="button" class="scelta" class:attiva={ruoli.includes(chiave)} onclick={() => alternaRuolo(chiave)}>{testo}</button>
        {/each}
      </div>
    </div>
    {#if !nomeBloccato && notifiche.stato === 'spente'}<p class="aiuto">Premendo Continua attiviamo le notifiche: ti avvisiamo quando ti accettano, ti invitano o ti scrivono. Puoi spegnerle dal Profilo.</p>{/if}
    {#if errore}<div class="errore">{errore}</div>{/if}
    <button class="btn" type="submit" disabled={occupato}>{occupato ? 'Salvataggio…' : nomeBloccato ? 'Salva' : 'Continua'}</button>
  </form>
</div>

<style>
  .foto-riga { display:flex; flex-direction: row; align-items: center; gap: 14px; }
  .link-piccolo { background: none; border: none; color: var(--testo-2); text-decoration: underline; font-size: 13px; min-height: 32px; text-align: left; padding: 0; }
</style>
