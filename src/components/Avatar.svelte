<script>
  // Cerchio con la foto del giocatore, oppure le sue iniziali
  import { iniziali } from '../lib/formato.js'
  let { profilo = null, dimensione = 44, classe = '' } = $props()
  let errore = $state(false)
  $effect(() => { profilo?.foto_url; errore = false })
</script>

{#if profilo?.foto_url && !errore}
  <img class="avatar-foto {classe}" src={profilo.foto_url} alt={profilo?.nome ? `Foto di ${profilo.nome}` : 'Foto'}
       width={dimensione} height={dimensione} loading="lazy" decoding="async" onerror={() => (errore = true)}
       style={`width:${dimensione}px; height:${dimensione}px`} />
{:else}
  <span class="avatar {classe}" style={`width:${dimensione}px; height:${dimensione}px; border-radius:50%; font-size:${Math.round(dimensione * 0.36)}px`}>{iniziali(profilo)}</span>
{/if}

<style>
  .avatar-foto { border-radius: 50%; object-fit: cover; flex: 0 0 auto; display: block; background: var(--neutro); }
</style>
