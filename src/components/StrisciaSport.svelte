<script>
  // Striscia in alto nelle pagine con la barra: dice sempre in che sport si è (cambia con il pallone in basso)
  import Icona from './Icona.svelte'
  import { sport, NOMI_SPORT } from '../lib/sport.svelte.js'
</script>

<div class="striscia no-stampa" role="status" aria-live="polite">
  <Icona nome={sport.attuale} dimensione={16} spessore={2} />
  <span>Stai guardando: <strong>{NOMI_SPORT[sport.attuale]}</strong></span>
  <span class="suggerimento">cambia col tasto in basso</span>
</div>
{#if sport.appenaCambiato}
  {#key sport.attuale}<div class="lampo no-stampa" aria-hidden="true">Ora sei su {NOMI_SPORT[sport.attuale]}</div>{/key}
{/if}

<style>
  .striscia {
    display: flex; align-items: center; gap: 8px; padding: 6px 20px; font-size: 12.5px;
    background: var(--sport-chiaro); color: var(--sport); transition: background-color .4s, color .4s;
  }
  .striscia strong { font-weight: 700; }
  .suggerimento { margin-left: auto; color: var(--testo-2); font-size: 11.5px; }
  .lampo {
    position: fixed; left: 50%; bottom: calc(96px + var(--safe-bottom)); transform: translateX(-50%); z-index: 30;
    background: var(--sport); color: #fff; font-weight: 700; font-size: 15px; padding: 10px 18px; border-radius: 999px;
    box-shadow: 0 4px 14px rgba(0,0,0,.2); animation: compari 2.2s ease forwards; pointer-events: none; white-space: nowrap;
  }
  @keyframes compari { 0% { opacity: 0; transform: translate(-50%, 10px); } 12%, 80% { opacity: 1; transform: translate(-50%, 0); } 100% { opacity: 0; } }
  @media (prefers-reduced-motion: reduce) { .lampo { animation: none; } }
</style>
