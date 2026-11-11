<script>
  // Scritta "Ne manca 1": l'1 sta dentro il posto libero tratteggiato del campo
  let { dimensione = 26, chiaro = false, soloSimbolo = false } = $props()
</script>

<span class="logo" class:chiaro style={`font-size:${dimensione}px`} aria-label="Ne manca 1">
  {#if !soloSimbolo}<span class="testo">Ne manca</span>{/if}
  <span class="uno" aria-hidden="true">1</span>
</span>

<style>
  .logo { display: inline-flex; align-items: center; gap: 0.32em; font-family: var(--font-titoli); font-weight: 700; letter-spacing: -0.02em; color: var(--testo); line-height: 1; }
  .logo.chiaro { color: #fff; }
  .uno {
    width: 1.3em; height: 1.3em; border-radius: 50%; box-sizing: border-box;
    border: 0.1em dashed currentColor; display: inline-flex; align-items: center; justify-content: center;
    font-size: 1em; padding-left: 0.02em; color: var(--verde); background: var(--verde-chiaro);
  }
  .logo.chiaro .uno { color: #fff; background: rgba(255,255,255,0.16); }
</style>
