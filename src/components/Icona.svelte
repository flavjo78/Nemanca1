<script>
  // Icone SVG a tratto (niente emoji). Uso: <Icona nome="home" />
  let { nome, dimensione = 24, spessore = 2 } = $props()
  const tracciati = {
    home: '<path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
    campi: '<path d="M12 21s-6-5.3-6-11a6 6 0 0 1 12 0c0 5.7-6 11-6 11z"/><circle cx="12" cy="10" r="2.2"/>',
    chat: '<path d="M4 5h16v11H9l-5 4z"/>',
    profilo: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    indietro: '<path d="M15 5l-7 7 7 7"/>',
    avanti: '<path d="M9 5l7 7-7 7"/>',
    piu: '<path d="M12 5v14M5 12h14"/>',
    spunta: '<path d="M5 12l5 5L19 7"/>',
    x: '<path d="M6 6l12 12M18 6L6 18"/>',
    qr: '<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><path d="M14 14h3v3M21 14v7h-7"/>',
    condividi: '<path d="M4 12v7a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-7M12 15V3M7 8l5-5 5 5"/>',
    posizione: '<path d="M12 3v2M12 19v2M3 12h2M19 12h2"/><circle cx="12" cy="12" r="6"/>',
    cerca: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
    stampa: '<path d="M6 9V3h12v6M6 18H4a1 1 0 0 1-1-1v-6a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v6a1 1 0 0 1-1 1h-2"/><rect x="6" y="14" width="12" height="7"/>',
    esci: '<path d="M10 17l5-5-5-5M15 12H3M12 3h7a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1h-7"/>',
    orologio: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    utenti: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 7M21.5 20a6.5 6.5 0 0 0-5-6.3"/>',
    matita: '<path d="M4 20h4l10-10-4-4L4 16zM13 7l4 4"/>',
    mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
    ricarica: '<path d="M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5"/>'
  }
</script>

<svg aria-hidden="true" width={dimensione} height={dimensione} viewBox="0 0 24 24" fill="none"
  stroke="currentColor" stroke-width={spessore} stroke-linecap="round" stroke-linejoin="round">
  {@html tracciati[nome] ?? ''}
</svg>
