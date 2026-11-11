<script>
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { naviga } from '../lib/router.svelte.js'
  import { cercaIndirizzo, posizioneAttuale } from '../lib/geo.js'
  import Intestazione from '../components/Intestazione.svelte'
  import Icona from '../components/Icona.svelte'

  const SPORT = [
    { chiave: 'calcio', testo: 'Calcio' },
    { chiave: 'padel', testo: 'Padel (presto)' },
    { chiave: 'tennis', testo: 'Tennis (presto)' }
  ]
  let nome = $state('')
  let indirizzoTesto = $state('')
  let scelto = $state(null)
  let suggerimenti = $state([])
  let sport = $state(['calcio'])
  let errore = $state('')
  let occupato = $state(false)
  let cercando = $state(false)
  let timer

  function cambiaIndirizzo(e) {
    indirizzoTesto = e.target.value
    scelto = null
    clearTimeout(timer)
    timer = setTimeout(async () => {
      cercando = true
      try { suggerimenti = await cercaIndirizzo(indirizzoTesto) } catch { suggerimenti = [] }
      cercando = false
    }, 600)
  }
  function scegli(s) { scelto = s; indirizzoTesto = s.breve; suggerimenti = [] }

  async function usaPosizione() {
    errore = ''
    try {
      const { lat, lng } = await posizioneAttuale()
      const r = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}`, { headers: { 'Accept-Language': 'it' } })
      const x = await r.json()
      const a = x.address ?? {}
      const via = [a.road, a.house_number].filter(Boolean).join(' ')
      const comune = a.city || a.town || a.village || a.municipality || ''
      scelto = { breve: [via, comune].filter(Boolean).join(', ') || x.display_name, comune, lat, lng }
      indirizzoTesto = scelto.breve
      suggerimenti = []
    } catch {
      errore = 'Non riesco a leggere la posizione del telefono. Scrivi l\'indirizzo.'
    }
  }

  function alternaSport(s) { sport = sport.includes(s) ? sport.filter((x) => x !== s) : [...sport, s] }

  async function salva(e) {
    e.preventDefault()
    errore = ''
    if (nome.trim().length < 3) { errore = 'Scrivi il nome del campo.'; return }
    if (!scelto) { errore = 'Scegli l\'indirizzo dall\'elenco (o usa la posizione del telefono).'; return }
    if (!sport.length) { errore = 'Scegli almeno uno sport.'; return }
    occupato = true
    const { data, error } = await supabase.from('campi').insert({
      nome: nome.trim(), indirizzo: scelto.breve, lat: scelto.lat, lng: scelto.lng, sport, creato_da: auth.utente.id
    }).select('id').single()
    occupato = false
    if (error) { errore = error.message; return }
    naviga(`/campo/${data.id}?nuovo=1`, { sostituisci: true })
  }
</script>

<div class="pagina">
  <Intestazione titolo="Registra un campo" sotto="Poi stampi il QR e lo attacchi sul posto" ritorno="/campi" />
  <form class="contenuto" onsubmit={salva}>
    <div class="campo-form">
      <label for="nome">Nome del campo</label>
      <input id="nome" class="input" type="text" required bind:value={nome} placeholder="Campo San Rocco" />
    </div>
    <div class="campo-form">
      <label for="indirizzo">Indirizzo</label>
      <input id="indirizzo" class="input" type="text" value={indirizzoTesto} oninput={cambiaIndirizzo} placeholder="Via dei Pini 12, Galatina" autocomplete="off" />
      {#if suggerimenti.length}
        <div class="suggerimenti">
          {#each suggerimenti as s}
            <button type="button" onclick={() => scegli(s)}>{s.etichetta}</button>
          {/each}
        </div>
      {/if}
      <p class="aiuto">{cercando ? 'Cerco…' : scelto ? `Posizione trovata: ${scelto.breve}` : 'Scrivi via e comune, poi scegli dall\'elenco.'}</p>
      <button type="button" class="btn bianco piccolo" onclick={usaPosizione}>
        <Icona nome="posizione" dimensione={18} /> Sono sul campo: usa la mia posizione
      </button>
    </div>
    <div class="campo-form">
      <span class="aiuto" style="font-weight:600">Sport</span>
      <div class="scelte">
        {#each SPORT as s}
          <button type="button" class="scelta" class:attiva={sport.includes(s.chiave)} onclick={() => alternaSport(s.chiave)}>{s.testo}</button>
        {/each}
      </div>
    </div>
    {#if errore}<div class="errore">{errore}</div>{/if}
    <button class="btn" type="submit" disabled={occupato}>{occupato ? 'Salvataggio…' : 'Salva il campo'}</button>
  </form>
</div>
