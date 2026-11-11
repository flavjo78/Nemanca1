<script>
  import Icona from './Icona.svelte'
  import { router } from '../lib/router.svelte.js'
  const voci = [
    { href: '/', nome: 'home', testo: 'Home' },
    { href: '/campi', nome: 'campi', testo: 'Campi' },
    { href: '/chat', nome: 'chat', testo: 'Chat' },
    { href: '/profilo', nome: 'profilo', testo: 'Profilo' }
  ]
  function attiva(href) {
    return href === '/' ? router.percorso === '/' : router.percorso.startsWith(href)
  }
</script>

<nav class="barra-inferiore no-stampa" aria-label="Navigazione principale">
  {#each voci as v}
    <a href={v.href} class:attiva={attiva(v.href)} aria-current={attiva(v.href) ? 'page' : undefined}>
      <Icona nome={v.nome} />
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
</style>
