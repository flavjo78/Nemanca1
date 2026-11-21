// Sport scelto con il tasto al centro della barra in basso: calcio → tennis → padel.
// Si ricorda sul dispositivo; Home, Campi, Profilo e "Organizza" seguono lo sport scelto.
export const ORDINE_SPORT = ['calcio', 'tennis', 'padel']
export const NOMI_SPORT = { calcio: 'Calcio', tennis: 'Tennis', padel: 'Padel' }
export const FORMATI = { calcio: [5, 8, 11], tennis: [1, 2], padel: [1, 2] }
const CHIAVE = 'nm1-sport'

function leggi() {
  try { const s = localStorage.getItem(CHIAVE); return ORDINE_SPORT.includes(s) ? s : 'calcio' } catch { return 'calcio' }
}

export const sport = $state({ attuale: leggi() })

export function scegliSport(s) {
  if (!ORDINE_SPORT.includes(s)) return
  sport.attuale = s
  try { localStorage.setItem(CHIAVE, s) } catch { /* niente */ }
}

export function prossimoSport() {
  scegliSport(ORDINE_SPORT[(ORDINE_SPORT.indexOf(sport.attuale) + 1) % ORDINE_SPORT.length])
}

/** Tennis e padel: si gioca 1 contro 1 o 2 contro 2, senza modulo né divise. */
export const racchetta = (s) => s === 'tennis' || s === 'padel'
