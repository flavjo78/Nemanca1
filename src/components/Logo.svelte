<script>
  // Scritta "Ne manca 1" (variante 5): Outfit nero inclinato + l'1 nel posto libero tratteggiato.
  // slogan: aggiunge "Trova chi manca in campo" sotto. verticale: cerchio sopra la scritta (QR stampati, splash).
  let { dimensione = 26, chiaro = false, soloSimbolo = false, slogan = false, verticale = false } = $props()
</script>

<span class="logo" class:chiaro class:verticale style={`font-size:${dimensione}px`} aria-label="Ne manca 1">
  <span class="riga">
    {#if verticale}<span class="uno" aria-hidden="true">1</span>{/if}
    {#if !soloSimbolo}<span class="testo">Ne manca</span>{/if}
    {#if !verticale}<span class="uno" aria-hidden="true">1</span>{/if}
  </span>
  {#if slogan}<span class="slogan">Trova chi manca in campo</span>{/if}
</span>

<style>
  .logo { display: inline-flex; flex-direction: column; align-items: flex-start; gap: 0.38em; color: var(--testo); line-height: 1; }
  .logo.chiaro { color: #fff; }
  .riga { display: inline-flex; align-items: center; gap: 0.3em; }
  .verticale .riga { flex-direction: column; gap: 0.35em; }
  .verticale { align-items: center; }
  .testo {
    font-family: Outfit, var(--font-titoli); font-weight: 900; letter-spacing: -0.03em;
    transform: skewX(-8deg); display: inline-block; padding-right: 0.06em;
  }
  .uno {
    width: 1.3em; height: 1.3em; border-radius: 50%; box-sizing: border-box;
    border: 0.1em dashed currentColor; display: inline-flex; align-items: center; justify-content: center;
    font-family: var(--font-titoli); font-weight: 700; font-size: 1em; padding-left: 0.02em;
    color: var(--verde); background: var(--verde-chiaro);
  }
  .logo.chiaro .uno { color: #fff; background: rgba(255,255,255,0.16); }
  .slogan {
    font-family: var(--font); font-weight: 600; font-size: 0.42em; letter-spacing: 0.14em;
    text-transform: uppercase; color: var(--verde); padding-left: 0.1em;
  }
  .logo.chiaro .slogan { color: var(--verde-chiaro); }
</style>
