<script>
  import Icona from './Icona.svelte'
  import { indietro } from '../lib/router.svelte.js'
  let { titolo, sotto = '', ritorno = '/', destra } = $props()
</script>

<header class="intestazione">
  <button type="button" class="btn-tondo no-stampa" aria-label="Torna indietro" onclick={() => indietro(ritorno)}>
    <Icona nome="indietro" dimensione={20} spessore={2.4} />
  </button>
  <div class="centro">
    <h1>{titolo}</h1>
    {#if sotto}<div class="sotto">{sotto}</div>{/if}
  </div>
  {#if destra}{@render destra()}{/if}
</header>
