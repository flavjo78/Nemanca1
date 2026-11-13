<script>
  // Disegno del completino: maglietta e pantaloncini nei colori scelti
  import { hex } from '../lib/divise.js'
  let { maglia = 'bianco', pantaloncini = 'nero', dimensione = 28, titolo = '' } = $props()
</script>

<svg width={dimensione} height={dimensione * 1.15} viewBox="0 0 40 46" role={titolo ? 'img' : 'presentation'} aria-label={titolo || undefined} aria-hidden={titolo ? undefined : 'true'}>
  <!-- maglietta -->
  <path d="M13 2 L7 4 L1 11 L6 16 L9 13 L9 27 L31 27 L31 13 L34 16 L39 11 L33 4 L27 2 Q20 7 13 2 Z"
        fill={hex(maglia)} stroke="#14201A" stroke-width="1.6" stroke-linejoin="round" />
  <!-- pantaloncini -->
  <path d="M9 30 L31 30 L33 44 L22 44 L20 36 L18 44 L7 44 Z"
        fill={hex(pantaloncini)} stroke="#14201A" stroke-width="1.6" stroke-linejoin="round" />
</svg>
