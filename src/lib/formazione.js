// Disposizione automatica dei posti sul campo: per ogni squadra, una riga per ruolo,
// posti distribuiti in orizzontale. Così lo schema resta ordinato anche quando
// l'organizzatore aggiunge o toglie posti.
const RIGHE = { portiere: 8, difesa: 34, centro: 60, attacco: 86 }
const COLONNE = { 1: [50], 2: [30, 70], 3: [22, 50, 78], 4: [15, 38, 62, 85] }
const ORDINE = ['portiere', 'difesa', 'centro', 'attacco']

/** Ruolo dedotto dall'altezza nella metà campo (0 = propria porta, 100 = metà campo); stesse soglie del DB. */
export function ruoloDaAltezza(y) {
  return y < 47 ? 'difesa' : y < 73 ? 'centro' : 'attacco'
}

/** Ritorna una mappa id → {x, y} (percentuali nella metà campo, y=0 porta propria).
 *  I posti spostati a mano (manuale) restano dove sono; gli altri si dispongono in righe per ruolo. */
export function disponi(posizioni) {
  const coordinate = {}
  for (const p of posizioni) if (p.manuale && p.ruolo !== 'panchina') coordinate[p.id] = { x: p.x, y: p.y }
  for (const squadra of ['A', 'B']) {
    const mie = posizioni.filter((p) => p.squadra === squadra && p.ruolo !== 'panchina' && !p.manuale)
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
  const campo = posizioni.filter((p) => p.ruolo !== 'panchina')
  const panchina = posizioni.filter((p) => p.ruolo === 'panchina')
  const liberi = campo.filter((p) => p.stato === 'libera')
  return {
    totale: campo.length,
    occupati: campo.length - liberi.length,
    liberi: liberi.length,
    ruoliLiberi: [...new Set(liberi.map((p) => p.ruolo))],
    panchinaTotale: panchina.length,
    panchinaLiberi: panchina.filter((p) => p.stato === 'libera').length
  }
}

// Modulo senza portiere (è sempre 1): "2-2", "1-2-1", "3-3-1"...
export const PREDEFINITI = { 5: { difesa: 2, centro: 0, attacco: 2 }, 8: { difesa: 3, centro: 3, attacco: 1 }, 11: { difesa: 4, centro: 4, attacco: 2 } }

export function testoModulo({ difesa, centro, attacco }) {
  return centro ? `${difesa}-${centro}-${attacco}` : `${difesa}-${attacco}`
}

/** Stringa per il database: sempre con il portiere davanti, es. "1-2-0-2". */
export function moduloPerDb({ difesa, centro, attacco }) {
  return `1-${difesa}-${centro}-${attacco}`
}

/** Conteggio dei ruoli in campo di una squadra (portiere escluso). */
export function contaRuoli(posizioni, squadra) {
  const c = { difesa: 0, centro: 0, attacco: 0 }
  for (const p of posizioni) if (p.squadra === squadra && c[p.ruolo] !== undefined) c[p.ruolo]++
  return c
}

/** Modulo attuale di una squadra, es. "2-2" o "1-2-1". */
export function moduloDi(posizioni, squadra) {
  return testoModulo(contaRuoli(posizioni, squadra))
}
