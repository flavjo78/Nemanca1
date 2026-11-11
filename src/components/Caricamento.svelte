<script>
  let { testo = '' } = $props()
</script>
<div class="centrato" style="flex-direction: column; gap: 12px; padding: 40px 20px; min-height: 160px">
  <div class="spinner"></div>
  {#if testo}<div class="aiuto">{testo}</div>{/if}
</div>
