<script>
  // Campo da calcio con le due squadre in formazione (dal mockup partita.html).
  // Squadra A in alto, squadra B in basso. Ogni posto è toccabile se c'è `alClick`.
  import Icona from './Icona.svelte'
  import { etichettaRuolo, iniziali } from '../lib/formato.js'
  import { disponi } from '../lib/formazione.js'
  let { posizioni = [], mioId = null, alClick = null, evidenzia = null } = $props()

  const coordinate = $derived(disponi(posizioni))

  function stile(p) {
    const c = coordinate[p.id] ?? { x: p.x, y: p.y }
    // metà campo mappata su 5%–95% così pallino e targhetta restano dentro il bordo
    const top = p.squadra === 'A' ? 5 + (c.y / 2) * 0.9 : 95 - (c.y / 2) * 0.9
    return `left:${c.x}%; top:${top}%`
  }
  function classiPallino(p) {
    let c = 'pallino-posto'
    if (p.stato === 'libera') c += ' libero'
    else if (p.ruolo === 'portiere') c += ' portiere'
    if (p.giocatore_id && p.giocatore_id === mioId) c += ' mio'
    if (evidenzia && evidenzia(p)) c += ' evidenziato'
    return c
  }
  function etichetta(p) {
    if (p.stato === 'libera') return `${etichettaRuolo(p.ruolo)} libero`
    if (p.stato === 'cambio_proposto') return 'Cambio proposto'
    const base = etichettaRuolo(p.ruolo)
    return p.giocatore_id === mioId ? `Tu · ${base}` : base
  }
  function ariaLabel(p) {
    if (p.stato === 'libera') return `Posto libero: ${etichettaRuolo(p.ruolo)}, squadra ${p.squadra}`
    return `${p.giocatore?.nome ?? 'Giocatore'}, ${etichettaRuolo(p.ruolo)}, squadra ${p.squadra}`
  }
</script>

<div class="campo" role="group" aria-label="Formazione delle due squadre">
  <div class="meta"></div>
  <div class="cerchio"></div>
  <div class="area alto"></div>
  <div class="area basso"></div>
  <div class="nome-squadra alto">SQUADRA A</div>
  <div class="nome-squadra basso">SQUADRA B</div>

  {#each posizioni as p (p.id)}
    <div class="posto" style={stile(p)}>
      {#if alClick}
        <button type="button" class={classiPallino(p)} aria-label={ariaLabel(p)} onclick={() => alClick(p)}>
          {#if p.stato === 'libera'}<Icona nome="piu" dimensione={20} spessore={2.6} />{:else}{iniziali(p.giocatore)}{/if}
          {#if p.stato === 'cambio_proposto'}<span class="badge-domanda">?</span>{/if}
        </button>
      {:else}
        <div class={classiPallino(p)}>
          {#if p.stato === 'libera'}<Icona nome="piu" dimensione={20} spessore={2.6} />{:else}{iniziali(p.giocatore)}{/if}
          {#if p.stato === 'cambio_proposto'}<span class="badge-domanda">?</span>{/if}
        </div>
      {/if}
      <div class="targhetta" class:libera={p.stato === 'libera'} class:portiere={p.stato === 'libera' && p.ruolo === 'portiere'}>{etichetta(p)}</div>
    </div>
  {/each}
</div>

<style>
  .campo {
    position: relative; width: 100%; aspect-ratio: 350 / 520; border-radius: 14px;
    background: repeating-linear-gradient(180deg, var(--campo) 0px, var(--campo) 12.5%, var(--campo-2) 12.5%, var(--campo-2) 25%);
    border: 3px solid #fff; overflow: hidden; max-width: 420px; margin: 0 auto; flex: none;
  }
  .meta { position: absolute; left: 0; right: 0; top: 50%; height: 2px; background: rgba(255,255,255,0.85); }
  .cerchio { position: absolute; left: 50%; top: 50%; width: 26%; aspect-ratio: 1; transform: translate(-50%, -50%); border: 2px solid rgba(255,255,255,0.85); border-radius: 50%; }
  .area { position: absolute; left: 50%; width: 46%; height: 11%; transform: translateX(-50%); border: 2px solid rgba(255,255,255,0.85); }
  .area.alto { top: 0; border-top: none; }
  .area.basso { bottom: 0; border-bottom: none; }
  .nome-squadra { position: absolute; left: 10px; font-size: 11px; font-weight: 700; color: #fff; background: rgba(0,0,0,0.28); padding: 4px 8px; border-radius: 999px; pointer-events: none; }
  .nome-squadra.alto { top: 10px; } .nome-squadra.basso { bottom: 10px; }
  .posto { position: absolute; width: 64px; transform: translate(-50%, -50%); display: flex; flex-direction: column; align-items: center; gap: 3px; transition: left .25s, top .25s; }
  .pallino-posto {
    width: 44px; height: 44px; border-radius: 22px; background: #fff; color: var(--testo);
    font-size: 13px; font-weight: 700; display: flex; align-items: center; justify-content: center;
    border: 3px solid #fff; position: relative; padding: 0; font-family: var(--font);
  }
  button.pallino-posto { cursor: pointer; }
  button.pallino-posto:active { transform: scale(0.94); }
  .pallino-posto.portiere { background: var(--portiere); }
  .pallino-posto.mio { background: var(--verde); color: #fff; }
  .pallino-posto.libero { background: rgba(255,255,255,0.18); color: #fff; border-style: dashed; }
  .pallino-posto.evidenziato { box-shadow: 0 0 0 4px rgba(240,179,91,0.9); }
  .badge-domanda {
    position: absolute; top: -6px; right: -6px; width: 18px; height: 18px; border-radius: 9px;
    background: var(--da-confermare); color: #fff; font-size: 10px; font-weight: 700;
    display: flex; align-items: center; justify-content: center; border: 2px solid #fff;
  }
  .targhetta { font-size: 10px; font-weight: 600; color: #fff; background: rgba(0,0,0,0.35); padding: 2px 6px; border-radius: 999px; white-space: nowrap; pointer-events: none; }
  .targhetta.libera { font-weight: 700; }
  .targhetta.portiere { color: var(--testo); background: var(--portiere); }
</style>
