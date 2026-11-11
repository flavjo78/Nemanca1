<script>
  // Profilo: voto, partite, vinte, barre per categoria, storico, campi frequentati
  import { onMount } from 'svelte'
  import { supabase } from '../lib/supabase.js'
  import { auth, esci } from '../lib/auth.svelte.js'
  import { naviga } from '../lib/router.svelte.js'
  import { iniziali, etichettaRuolo, etichettaFormato } from '../lib/formato.js'
  import BarraInferiore from '../components/BarraInferiore.svelte'
  import Icona from '../components/Icona.svelte'

  let voti = $state(null)
  let storico = $state([])
  let caricato = $state(false)

  const p = $derived(auth.profilo)
  const giocate = $derived(storico.filter((s) => s.stato === 'giocata').length)
  const vinte = $derived(storico.filter((s) => s.esito === 'vinta').length)
  const campiFrequentati = $derived(Object.entries(storico.reduce((acc, s) => { acc[s.campo_nome] = (acc[s.campo_nome] || 0) + 1; return acc }, {}))
    .sort((a, b) => b[1] - a[1]).slice(0, 5).map(([nome]) => nome))
  const anno = $derived(new Date(p?.creato_il ?? Date.now()).getFullYear())
  const categorie = [['puntualita', 'Puntualità'], ['correttezza', 'Correttezza'], ['livello', 'Livello tecnico'], ['squadra', 'Spirito di squadra']]

  onMount(async () => {
    const [{ data: v }, { data: s }] = await Promise.all([
      supabase.from('profili_voti').select('*').eq('profilo_id', auth.utente.id).maybeSingle(),
      supabase.from('storico_partite').select('*').eq('giocatore_id', auth.utente.id).order('data_ora', { ascending: false }).limit(20)
    ])
    voti = v
    storico = s ?? []
    caricato = true
  })

  function virgola(n) { return n == null ? '–' : Number(n).toFixed(1).replace('.', ',') }
  function risultato(s) {
    if (s.risultato_a == null) return '–'
    return s.squadra === 'A' ? `${s.risultato_a}-${s.risultato_b}` : `${s.risultato_b}-${s.risultato_a}`
  }
  function esitoTesto(s) { return { vinta: 'Vittoria', persa: 'Sconfitta', pareggio: 'Pareggio' }[s.esito] ?? (s.stato === 'annullata' ? 'Annullata' : 'Da giocare') }
  function dataBreve(d) { d = new Date(d); return `${d.getDate()} ${['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'][d.getMonth()]}` }
  async function logout() { await esci(); naviga('/login', { sostituisci: true }) }
</script>

<div class="pagina">
  <header class="intestazione" style="justify-content: space-between">
    <div class="centro"><h1 style="font-size:26px">Profilo e storico</h1></div>
    <button type="button" class="btn-tondo" aria-label="Modifica profilo" onclick={() => naviga('/profilo/modifica')}><Icona nome="matita" dimensione={20} /></button>
  </header>

  <div class="contenuto con-barra">
    <div class="card riga" style="padding: 16px">
      <div class="avatar verde" style="width:56px; height:56px; border-radius:28px; font-size:20px">{iniziali(p)}</div>
      <div class="riempi">
        <div class="nome" style="font-size:18px; font-family: var(--font-titoli)">{p?.nome ?? 'Giocatore'}</div>
        <div class="sotto">{[p?.comune, (p?.ruoli_preferiti ?? []).map(etichettaRuolo).join(', ')].filter(Boolean).join(' · ')}{p?.comune || p?.ruoli_preferiti?.length ? ' · ' : ''}dal {anno}</div>
      </div>
    </div>

    <div style="display:grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px">
      {#each [[virgola(voti?.complessivo), 'Voto'], [giocate, 'Partite'], [vinte, 'Vinte']] as [n, t]}
        <div class="card" style="align-items:center; gap:2px; padding: 14px 8px">
          <div style="font-family: var(--font-titoli); font-size: 26px; font-weight: 700">{n}</div>
          <div class="sotto" style="text-transform: uppercase; letter-spacing: .6px; font-size: 11px; font-weight: 600">{t}</div>
        </div>
      {/each}
    </div>

    <section class="sezione">
      <div class="sezione-titolo">Come ti valutano</div>
      <div class="card" style="gap: 12px">
        {#each categorie as [chiave, testo]}
          <div style="display:flex; flex-direction:column; gap:6px">
            <div style="display:flex; justify-content:space-between; font-size:14px"><span>{testo}</span><strong>{virgola(voti?.[chiave])}</strong></div>
            <div class="barra" style="flex:none"><div style={`width:${voti ? (voti[chiave] / 5) * 100 : 0}%`}></div></div>
          </div>
        {/each}
        <p class="aiuto">{voti ? `Media di ${voti.n_recensioni} recensioni anonime` : 'Ancora nessuna recensione: arrivano dopo le prime partite giocate.'}</p>
      </div>
    </section>

    <section class="sezione">
      <div class="sezione-titolo">Storico partite</div>
      {#if !caricato}
        <div class="vuoto">Caricamento…</div>
      {:else if storico.length}
        {#each storico as s (s.partita_id)}
          <a href={`/partita/${s.partita_id}`} class="card riga">
            <div class="data-box" style={s.esito === 'vinta' ? 'background: var(--verde-chiaro); color: var(--verde-scuro)' : s.esito ? '' : 'background: var(--neutro); color: var(--testo-3)'}>
              <div class="n" style="font-size:15px">{risultato(s)}</div>
            </div>
            <div class="riempi">
              <div class="nome">{esitoTesto(s)} · {etichettaFormato(s.formato)}</div>
              <div class="sotto taglia">{s.campo_nome} · {dataBreve(s.data_ora)}</div>
            </div>
            <Icona nome="avanti" dimensione={18} />
          </a>
        {/each}
      {:else}
        <div class="vuoto">Le partite a cui partecipi compariranno qui.</div>
      {/if}
    </section>

    {#if campiFrequentati.length}
      <section class="sezione">
        <div class="sezione-titolo">I tuoi campi</div>
        <div class="chip-riga">{#each campiFrequentati as c}<span class="chip">{c}</span>{/each}</div>
      </section>
    {/if}

    {#if p?.admin}
      <a href="/admin" class="btn scuro"><Icona nome="utenti" dimensione={18} /> Area amministratore</a>
    {/if}
    <button type="button" class="btn bianco" onclick={logout}><Icona nome="esci" dimensione={18} /> Esci</button>
    <p class="aiuto" style="text-align:center">{auth.utente?.email}</p>
  </div>
  <BarraInferiore />
</div>
