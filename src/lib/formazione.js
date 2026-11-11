// Disposizione automatica dei posti sul campo: per ogni squadra, una riga per ruolo,
// posti distribuiti in orizzontale. Così lo schema resta ordinato anche quando
// l'organizzatore aggiunge o toglie posti.
const RIGHE = { portiere: 8, difesa: 34, centro: 60, attacco: 86 }
const COLONNE = { 1: [50], 2: [30, 70], 3: [22, 50, 78], 4: [15, 38, 62, 85] }
const ORDINE = ['portiere', 'difesa', 'centro', 'attacco']

/** Ritorna una mappa id → {x, y} (percentuali nella metà campo, y=0 porta propria). */
export function disponi(posizioni) {
  const coordinate = {}
  for (const squadra of ['A', 'B']) {
    const mie = posizioni.filter((p) => p.squadra === squadra)
    const ruoliPresenti = ORDINE.filter((r) => mie.some((p) => p.ruolo === r))
    // se mancano i centrocampisti, difesa e attacco si allontanano un po'
    const righe = { ...RIGHE }
    if (!ruoliPresenti.includes('centro')) { righe.difesa = 38; righe.attacco = 76 }
    for (const ruolo of ORDINE) {
      const fila = mie.filter((p) => p.ruolo === ruolo).sort((a, b) => a.x - b.x || a.creato_il?.localeCompare?.(b.creato_il) || 0)
      fila.forEach((p, i) => {
        const n = fila.length
        const x = COLONNE[n] ? COLONNE[n][i] : Math.round(10 + (80 * i) / (n - 1))
        coordinate[p.id] = { x, y: righe[ruolo] }
      })
    }
  }
  return coordinate
}

export function conta(posizioni) {
  const liberi = posizioni.filter((p) => p.stato === 'libera')
  return {
    totale: posizioni.length,
    occupati: posizioni.length - liberi.length,
    liberi: liberi.length,
    ruoliLiberi: [...new Set(liberi.map((p) => p.ruolo))]
  }
}
