<script>
  import Icona from './Icona.svelte'
  import { router } from '../lib/router.svelte.js'
  import { nonLetti } from '../lib/nonletti.svelte.js'
  const voci = [
    { href: '/', nome: 'home', testo: 'Home' },
    { href: '/campi', nome: 'campi', testo: 'Campi' },
    { href: '/chat', nome: 'chat', testo: 'Chat' },
    { href: '/profilo', nome: 'profilo', testo: 'Profilo' }
  ]
  function attiva(href) {
    if (href === '/chat' && router.percorso === '/amici') return true
    return href === '/' ? router.percorso === '/' : router.percorso.startsWith(href)
  }
</script>

<nav class="barra-inferiore no-stampa" aria-label="Navigazione principale">
  {#each voci as v}
    {@const n = v.nome === 'chat' ? nonLetti.totale : 0}
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
    display: grid; grid-template-columns: repeat(4, minmax(0, 1fr));
    padding: 10px 8px calc(10px + var(--safe-bottom)) 8px;
    max-width: 640px; margin: 0 auto;
  }
  a {
    text-decoration: none; color: var(--testo-2);
    display: flex; flex-direction: column; align-items: center; gap: 4px;
    font-size: 11px; font-weight: 600; min-height: 44px; justify-content: center;
  }
  a.attiva { color: var(--verde); }
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
