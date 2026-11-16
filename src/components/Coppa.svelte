<script>
  // Coppa in miniatura (apice sull'avatar): quante volte migliore in campo
  let { n = 0 } = $props()
</script>

{#if n > 0}
  <span class="coppa" title={`Migliore in campo ${n} ${n === 1 ? 'volta' : 'volte'}`} aria-label={`Migliore in campo ${n} ${n === 1 ? 'volta' : 'volte'}`}>
    <svg width="12" height="12" viewBox="0 0 24 24" fill="#fff" stroke="#fff" stroke-width="1.5" stroke-linejoin="round" aria-hidden="true">
      <path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3a3 3 0 0 1-3 4M7 5H4a3 3 0 0 0 3 4" fill="none"/>
    </svg>{#if n > 1}<span>{n}</span>{/if}
  </span>
{/if}

<style>
  .coppa {
    position: absolute; top: -4px; right: -6px; display: inline-flex; align-items: center; gap: 1px;
    min-width: 20px; height: 20px; padding: 0 4px; border-radius: 10px; background: #C99A2E;
    border: 2px solid var(--superficie); color: #fff; font: 700 10.5px Inter, sans-serif; box-sizing: border-box;
  }
</style>
