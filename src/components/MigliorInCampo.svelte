<script>
  // Dopo la partita (inizio + durata): riquadro OBBLIGATORIO "Vota il migliore in campo".
  // 1) scegli il migliore (o "Non c'ero"); 2) dai i voti ad almeno un compagno (gli altri facoltativi).
  // Si invia tutto insieme alla fine, così non si può saltare il secondo passo.
  import { supabase } from '../lib/supabase.js'
  import { auth } from '../lib/auth.svelte.js'
  import { dopoAvvio } from '../lib/avvio.js'
  import { etichettaRuolo, etichettaDataOra } from '../lib/formato.js'
  import Avatar from './Avatar.svelte'

  const CATEGORIE = [['puntualita', 'Puntualità'], ['correttezza', 'Correttezza'], ['livello', 'Livello tecnico'], ['squadra', 'Spirito di squadra']]

  let coda = $state([])        // partite da votare
  let passo = $state(1)
  let migliore = $state(null)
  let voti = $state({})        // { idGiocatore: { puntualita, correttezza, livello, squadra } }
  let aperto = $state(null)    // giocatore di cui si stanno dando i voti
  let occupato = $state(false)
  let errore = $state('')

  const attuale = $derived(coda[0] ?? null)
  const compagni = $derived((attuale?.candidati ?? []).filter((c) => c.id !== auth.utente?.id))
  const completo = (id) => CATEGORIE.every(([k]) => voti[id]?.[k] >= 1)
  const votatiCompleti = $derived(compagni.filter((c) => completo(c.id)))

  async function carica() {
    if (!auth.utente || !supabase) return
    await dopoAvvio()
    const { data } = await supabase.rpc('voti_da_dare')
    coda = (data ?? []).filter((p) => (p.candidati ?? []).some((c) => c.id !== auth.utente.id))
    reset()
  }
  function reset() { passo = 1; migliore = null; voti = {}; aperto = null; errore = '' }

  $effect(() => { if (auth.utente?.id && auth.profilo?.nome) carica() })
  // controlla di nuovo quando si torna sull'app (una partita può essere appena finita)
  $effect(() => {
    const f = () => { if (!document.hidden && auth.utente) carica() }
    document.addEventListener('visibilitychange', f)
    return () => document.removeEventListener('visibilitychange', f)
  })

  function dai(id, k, n) { voti = { ...voti, [id]: { ...(voti[id] ?? {}), [k]: n } } }

  async function nonCero() {
    occupato = true; errore = ''
    const { error } = await supabase.rpc('vota_mvp', { p_partita: attuale.partita_id, p_votato: null })
    occupato = false
    if (error) { errore = error.message; return }
    coda = coda.slice(1); reset()
  }

  async function invia() {
    if (!migliore || !votatiCompleti.length) return
    occupato = true; errore = ''
    try {
      for (const c of votatiCompleti) {
        const v = voti[c.id]
        const { error } = await supabase.rpc('dai_voti', { p_partita: attuale.partita_id, p_a: c.id,
          p_puntualita: v.puntualita, p_correttezza: v.correttezza, p_livello: v.livello, p_squadra: v.squadra })
        if (error) throw error
      }
      const { error } = await supabase.rpc('vota_mvp', { p_partita: attuale.partita_id, p_votato: migliore })
      if (error) throw error
      coda = coda.slice(1); reset()
    } catch (e) {
      errore = e.message ?? 'Non sono riuscito a inviare. Riprova.'
    } finally { occupato = false }
  }
</script>

{#if attuale}
  <div class="velo" role="dialog" aria-modal="true" aria-label="Vota il migliore in campo">
    <div class="riquadro">
      <div class="testa">
        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#C99A2E" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3a3 3 0 0 1-3 4M7 5H4a3 3 0 0 0 3 4"/>
        </svg>
        <div>
          <h2>{passo === 1 ? 'Vota il migliore in campo!' : 'Dai i voti ai compagni'}</h2>
          <div class="sotto">{etichettaDataOra(attuale.data_ora)} · {attuale.campo_nome}</div>
        </div>
      </div>

      {#if errore}<div class="errore">{errore}</div>{/if}

      {#if passo === 1}
        <p class="aiuto">Scegli chi ha giocato meglio. Il voto è anonimo.</p>
        <div class="griglia">
          {#each compagni as c (c.id)}
            <button type="button" class="giocatore" class:scelto={migliore === c.id} onclick={() => (migliore = c.id)} aria-pressed={migliore === c.id}>
              <Avatar profilo={c} dimensione={52} />
              <span class="nome">{c.nome}</span>
              <span class="ruolo">{etichettaRuolo(c.ruolo)} · {c.squadra}</span>
            </button>
          {/each}
        </div>
        <button type="button" class="btn" disabled={!migliore || occupato} onclick={() => (passo = 2)}>Avanti</button>
        <button type="button" class="link" disabled={occupato} onclick={nonCero}>Non c'ero a questa partita</button>
      {:else}
        <p class="aiuto">Dai i voti (da 1 a 5) ad <strong>almeno un compagno</strong>; gli altri sono facoltativi. Nessuno vedrà chi ha votato.</p>
        <div class="elenco">
          {#each compagni as c (c.id)}
            <div class="voto" class:pronto={completo(c.id)}>
              <button type="button" class="riga" onclick={() => (aperto = aperto === c.id ? null : c.id)} aria-expanded={aperto === c.id}>
                <Avatar profilo={c} dimensione={36} />
                <span class="nome riempi">{c.nome}</span>
                <span class="stato">{completo(c.id) ? 'Votato' : 'Vota'}</span>
              </button>
              {#if aperto === c.id}
                {#each CATEGORIE as [k, nomeCat]}
                  <div class="categoria">
                    <span>{nomeCat}</span>
                    <div class="stelle" role="radiogroup" aria-label={`${nomeCat} di ${c.nome}`}>
                      {#each [1, 2, 3, 4, 5] as n}
                        <button type="button" role="radio" aria-checked={voti[c.id]?.[k] === n} aria-label={`${n}`}
                          class:piena={(voti[c.id]?.[k] ?? 0) >= n} onclick={() => dai(c.id, k, n)}>★</button>
                      {/each}
                    </div>
                  </div>
                {/each}
              {/if}
            </div>
          {/each}
        </div>
        <button type="button" class="btn" disabled={!votatiCompleti.length || occupato} onclick={invia}>
          {occupato ? 'Invio…' : votatiCompleti.length ? `Invia (${votatiCompleti.length} ${votatiCompleti.length === 1 ? 'compagno votato' : 'compagni votati'})` : 'Vota almeno un compagno'}
        </button>
        <button type="button" class="link" disabled={occupato} onclick={() => (passo = 1)}>Indietro</button>
      {/if}
    </div>
  </div>
{/if}

<style>
  .velo { position: fixed; inset: 0; z-index: 900; background: rgba(14, 31, 22, .72); display: flex; align-items: flex-end; justify-content: center; }
  .riquadro {
    width: 100%; max-width: 640px; max-height: 92dvh; overflow-y: auto; background: var(--superficie);
    border-radius: 20px 20px 0 0; padding: 20px 16px calc(20px + env(safe-area-inset-bottom, 0px));
    display: flex; flex-direction: column; gap: 12px;
  }
  .testa { display: flex; gap: 12px; align-items: center; }
  h2 { margin: 0; font-family: var(--font-titoli); font-size: 22px; }
  .sotto { color: var(--testo-2); font-size: 13px; }
  .griglia { display: grid; grid-template-columns: repeat(auto-fill, minmax(100px, 1fr)); gap: 10px; }
  .giocatore {
    display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 12px 6px; min-height: 44px;
    border: 2px solid var(--bordo-2); border-radius: 16px; background: var(--superficie); font: inherit; color: inherit;
  }
  .giocatore.scelto { border-color: #C99A2E; background: #FFF6E0; }
  .giocatore .nome { font-weight: 600; font-size: 13px; text-align: center; }
  .giocatore .ruolo { font-size: 11.5px; color: var(--testo-2); }
  .elenco { display: flex; flex-direction: column; gap: 8px; }
  .voto { border: 1px solid var(--bordo-2); border-radius: 14px; padding: 4px 12px 8px; }
  .voto.pronto { border-color: var(--verde); }
  .voto .riga { display: flex; align-items: center; gap: 10px; width: 100%; min-height: 48px; background: none; border: none; font: inherit; color: inherit; padding: 0; }
  .voto .stato { font-size: 13px; color: var(--verde); font-weight: 600; }
  .categoria { display: flex; justify-content: space-between; align-items: center; gap: 8px; font-size: 14px; }
  .stelle { display: flex; }
  .stelle button { width: 40px; height: 44px; background: none; border: none; font-size: 26px; color: var(--bordo); padding: 0; }
  .stelle button.piena { color: #E0A82E; }
  .link { background: none; border: none; color: var(--testo-2); text-decoration: underline; font-size: 14px; min-height: 44px; }
</style>
