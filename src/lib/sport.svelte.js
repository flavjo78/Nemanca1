// Sport scelto con il tasto al centro della barra in basso: tutti → calcio → tennis → padel.
// "Tutti" mostra tutto (sfondo bianco, card colorate per sport); uno sport mostra solo le sue partite e i suoi campi.
// Si ricorda sul dispositivo.
export const SPORT = ['calcio', 'tennis', 'padel']
export const ORDINE_SPORT = ['tutti', ...SPORT]
export const NOMI_SPORT = { tutti: 'Tutti', calcio: 'Calcio', tennis: 'Tennis', padel: 'Padel' }
export const FORMATI = { calcio: [5, 8, 11], tennis: [1, 2], padel: [1, 2] }
const CHIAVE = 'nm1-sport'

function leggi() {
  try { const s = localStorage.getItem(CHIAVE); return ORDINE_SPORT.includes(s) ? s : 'tutti' } catch { return 'tutti' }
}

export const sport = $state({ attuale: leggi(), appenaCambiato: false })

// colore dello sfondo: l'attributo data-sport su <html> (vedi app.css)
function segna(s) { try { document.documentElement.dataset.sport = s } catch { /* niente */ } }
segna(sport.attuale)
let timer

export function scegliSport(s) {
  if (!ORDINE_SPORT.includes(s)) return
  sport.attuale = s
  segna(s)
  try { localStorage.setItem(CHIAVE, s) } catch { /* niente */ }
}

export function prossimoSport() {
  scegliSport(ORDINE_SPORT[(ORDINE_SPORT.indexOf(sport.attuale) + 1) % ORDINE_SPORT.length])
  // avviso breve "Ora sei su Tennis"
  sport.appenaCambiato = true
  clearTimeout(timer); timer = setTimeout(() => (sport.appenaCambiato = false), 2200)
}

/** Sport da passare al database: null = tutti. */
export const filtroSport = () => (sport.attuale === 'tutti' ? null : sport.attuale)
/** La partita/il campo di questo sport va mostrata con il filtro attuale? (accetta anche un elenco di sport) */
export function passaFiltro(s) {
  if (sport.attuale === 'tutti') return true
  return Array.isArray(s) ? s.includes(sport.attuale) : (s ?? 'calcio') === sport.attuale
}
/** Classe CSS per colorare una card: verde calcio, terra tennis, azzurro padel (più sport: a strisce). */
export function classeSport(s) {
  if (Array.isArray(s)) {
    const lista = sport.attuale !== 'tutti' && s.includes(sport.attuale) ? [sport.attuale] : s.filter((x) => SPORT.includes(x))
    return lista.length > 1 ? `card-sport sport-${lista.join('-')}` : `card-sport sport-${lista[0] ?? 'calcio'}`
  }
  return `card-sport sport-${s ?? 'calcio'}`
}
/** Sport da proporre quando si crea qualcosa. */
export const sportPredefinito = () => (sport.attuale === 'tutti' ? 'calcio' : sport.attuale)

/** Tennis e padel: si gioca 1 contro 1 o 2 contro 2, senza modulo né divise. */
export const racchetta = (s) => s === 'tennis' || s === 'padel'
