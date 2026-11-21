<script>
  import Icona from './Icona.svelte'
  import { router } from '../lib/router.svelte.js'
  import { nonLetti } from '../lib/nonletti.svelte.js'
  import { sport, prossimoSport, NOMI_SPORT, ORDINE_SPORT } from '../lib/sport.svelte.js'
  const dopo = $derived(NOMI_SPORT[ORDINE_SPORT[(ORDINE_SPORT.indexOf(sport.attuale) + 1) % ORDINE_SPORT.length]])
  const voci = [
    { href: '/', nome: 'home', testo: 'Home' },
    { href: '/campi', nome: 'campi', testo: 'Campi' },
    { href: '/chat', nome: 'chat', testo: 'Chat' },
    { href: '/profilo', nome: 'profilo', testo: 'Profilo' }
  ]
  function attiva(href) {
    if (href === '/chat' && (router.percorso === '/amici' || router.percorso === '/liste')) return true
    return href === '/' ? router.percorso === '/' : router.percorso.startsWith(href)
  }
</script>

<nav class="barra-inferiore no-stampa" aria-label="Navigazione principale">
  {#each voci as v, i}
    {@const n = v.nome === 'chat' ? nonLetti.totale : 0}
    {#if i === 2}
      <button type="button" class="sport" onclick={prossimoSport}
        aria-label={`Sport: ${NOMI_SPORT[sport.attuale]}. Tocca per passare a ${dopo}`}>
        {#key sport.attuale}<span class="tondo"><Icona nome={sport.attuale} dimensione={26} spessore={1.8} /></span>{/key}
        {NOMI_SPORT[sport.attuale]}
      </button>
    {/if}
    <a href={v.href} class:attiva={attiva(v.href)} aria-current={attiva(v.href) ? 'page' : undefined}
       aria-label={n ? `${v.testo}, ${n} ${n === 1 ? 'messaggio da leggere' : 'messaggi da leggere'}` : undefined}>
      <span class="icona">
        <Icona nome={v.nome} />
        {#if n}<span class="apice" class:lampeggia={n > 1}>{n > 99 ? '99+' : n}</span>{/if}
      </span>
      {v.testo}
    </a>
  {/each}
</nav>

<style>
  .barra-inferiore {
    position: fixed; left: 0; right: 0; bottom: 0; z-index: 20;
    background: var(--superficie); border-top: 1px solid var(--bordo-2);
    display: grid; grid-template-columns: repeat(5, minmax(0, 1fr));
    padding: 10px 8px calc(10px + var(--safe-bottom)) 8px;
    max-width: 640px; margin: 0 auto;
  }
  a {
    text-decoration: none; color: var(--testo-2);
    display: flex; flex-direction: column; align-items: center; gap: 4px;
    font-size: 11px; font-weight: 600; min-height: 44px; justify-content: center;
  }
  a.attiva { color: var(--verde); }
  /* tasto dello sport al centro: a ogni tocco calcio → tennis → padel */
  .sport {
    display: flex; flex-direction: column; align-items: center; gap: 2px; justify-content: center; min-height: 44px;
    background: none; border: none; padding: 0; font: inherit; font-size: 11px; font-weight: 700; color: var(--verde); cursor: pointer;
  }
  .sport .tondo {
    width: 46px; height: 46px; margin-top: -22px; border-radius: 50%; background: var(--verde); color: #fff;
    display: flex; align-items: center; justify-content: center; border: 3px solid var(--superficie);
    box-shadow: 0 2px 8px rgba(20, 32, 26, .25); animation: gira .35s ease-out;
  }
  .sport:active .tondo { transform: scale(.94); }
  @keyframes gira { from { transform: rotate(-120deg) scale(.8); opacity: .4; } to { transform: none; opacity: 1; } }
  @media (prefers-reduced-motion: reduce) { .sport .tondo { animation: none; } }
  .icona { position: relative; display: inline-flex; }
  .apice {
    position: absolute; top: -6px; right: -12px; min-width: 20px; height: 20px; padding: 0 5px;
    border-radius: 10px; background: #D93025; color: #fff; border: 2px solid var(--superficie);
    font-size: 11px; font-weight: 700; line-height: 16px; text-align: center; box-sizing: border-box;
  }
  /* più di un messaggio: lampeggia piano */
  .apice.lampeggia { animation: lampeggia 2.4s ease-in-out infinite; }
  @keyframes lampeggia { 0%, 100% { opacity: 1; } 50% { opacity: .35; } }
  @media (prefers-reduced-motion: reduce) { .apice.lampeggia { animation: none; } }
</style>
