<script>
  import BarraInferiore from '../components/BarraInferiore.svelte'
  import Icona from '../components/Icona.svelte'
  let { id = null } = $props()
</script>

<div class="pagina">
  <header class="intestazione"><div class="centro"><h1 style="font-size:26px">Chat</h1><div class="sotto">Le chat delle tue partite</div></div></header>
  <div class="contenuto con-barra">
    <div class="vuoto" style="display:flex; flex-direction:column; align-items:center; gap:10px; padding: 36px 16px">
      <span style="color: var(--verde)"><Icona nome="chat" dimensione={36} /></span>
      <strong style="color: var(--testo)">In arrivo con la tappa 3</strong>
      Qui vedrai la chat in tempo reale di ogni partita a cui partecipi, con le richieste da approvare.
      {#if id}<a href={`/partita/${id}`}>Torna alla partita</a>{/if}
    </div>
  </div>
  <BarraInferiore />
</div>
