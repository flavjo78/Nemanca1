<script>
  // Primo accesso: nome e comune (serve per "partite vicino a te")
  import { supabase } from '../lib/supabase.js'
  import { auth, caricaProfilo } from '../lib/auth.svelte.js'
  import { cercaComune } from '../lib/geo.js'
  import { naviga, router } from '../lib/router.svelte.js'
  import { RUOLI } from '../lib/formato.js'
  import { notifiche, attivaNotifiche } from '../lib/notifiche.svelte.js'

  let nome = $state(auth.profilo?.nome ?? '')
  // il nome si sceglie una volta sola (lo blocca anche il database)
  const nomeBloccato = !!auth.profilo?.nome?.trim()
  let comuneTesto = $state(auth.profilo?.comune ?? '')
  let comuneScelto = $state(auth.profilo?.comune ? { comune: auth.profilo.comune, lat: auth.profilo.lat, lng: auth.profilo.lng } : null)
  let suggerimenti = $state([])
  let ruoli = $state([...(auth.profilo?.ruoli_preferiti ?? [])])
  let errore = $state('')
  let occupato = $state(false)
  let timer

  function cambiaComune(e) {
    comuneTesto = e.target.value
    comuneScelto = null
    clearTimeout(timer)
    timer = setTimeout(async () => {
      try { suggerimenti = await cercaComune(comuneTesto) } catch { suggerimenti = [] }
    }, 500)
  }
  function scegli(s) { comuneScelto = s; comuneTesto = s.comune; suggerimenti = [] }
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
    if (comuneScelto) { dati.comune = comuneScelto.comune; dati.lat = comuneScelto.lat; dati.lng = comuneScelto.lng }
    else if (!comuneTesto.trim()) { dati.comune = null; dati.lat = null; dati.lng = null }
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
      <h1 style="font-size: 26px">Come ti chiami?</h1>
      <div class="sotto">Gli altri giocatori vedranno nome e iniziali.</div>
    </div>
  </div>
  <form class="contenuto" onsubmit={salva}>
    <div class="campo-form">
      <label for="nome">Nome e cognome</label>
      <input id="nome" class="input" type="text" autocomplete="name" required bind:value={nome} placeholder="Marco Rizzo" readonly={nomeBloccato} style={nomeBloccato ? 'background: var(--neutro); color: var(--testo-2)' : ''} />
      <p class="aiuto">{nomeBloccato ? 'Il nome non si può cambiare. Se è sbagliato scrivi a supporto@nemanca1.com.' : 'Scrivi nome e cognome veri: dopo non si potranno più cambiare.'}</p>
    </div>
    <div class="campo-form">
      <label for="comune">Il tuo comune</label>
      <input id="comune" class="input" type="text" value={comuneTesto} oninput={cambiaComune} placeholder="Galatina" autocomplete="off" />
      {#if suggerimenti.length}
        <div class="suggerimenti">
          {#each suggerimenti as s}
            <button type="button" onclick={() => scegli(s)}>{s.comune}{s.provincia ? ` · ${s.provincia}` : ''}</button>
          {/each}
        </div>
      {/if}
      <p class="aiuto">{comuneScelto ? `Scelto: ${comuneScelto.comune}` : 'Serve per mostrarti le partite vicine. Scegli dall\'elenco.'}</p>
    </div>
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
    <button class="btn" type="submit" disabled={occupato}>{occupato ? 'Salvataggio…' : 'Continua'}</button>
  </form>
</div>
