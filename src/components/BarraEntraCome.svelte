<script>
  // Barra in alto quando l'amministratore sta usando l'app come un altro utente
  import { auth } from '../lib/auth.svelte.js'
  import { sessioneAdmin, tornaAdmin } from '../lib/entracome.svelte.js'
  const admin = sessioneAdmin()
  const attiva = $derived(!!admin && auth.utente && auth.utente.id !== admin.id)
</script>

{#if attiva}
  <div class="barra" role="status">
    <span>Stai usando l'app come <strong>{auth.profilo?.nome ?? 'un altro utente'}</strong></span>
    <button type="button" onclick={tornaAdmin}>Torna amministratore</button>
  </div>
{/if}

<style>
  .barra {
    position: sticky; top: 0; z-index: 50; display: flex; align-items: center; justify-content: space-between; gap: 10px;
    background: #C2570A; color: #fff; padding: 8px 12px; font-size: 13px;
  }
  button { background: #fff; color: #C2570A; border: none; border-radius: 999px; min-height: 36px; padding: 0 12px; font: 700 13px Inter, sans-serif; white-space: nowrap; }
</style>
