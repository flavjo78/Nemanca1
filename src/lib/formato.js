// Etichette e formattazioni in italiano

const GIORNI = ['Domenica', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato']
const GIORNI_BREVI = ['DOM', 'LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB']
const MESI = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre']
const MESI_BREVI = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic']

export const RUOLI = {
  portiere: 'Portiere',
  difesa: 'Difesa',
  centro: 'Centrocampo',
  attacco: 'Attacco'
}

export function etichettaRuolo(r) { return r === 'panchina' ? 'Panchina' : (RUOLI[r] ?? r) }

export function etichettaFormato(f) { return `Calcio a ${f}` }

export function ora(d) {
  d = new Date(d)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}

function inizioGiorno(d) { const x = new Date(d); x.setHours(0, 0, 0, 0); return x }

/** "Oggi, 21:00" · "Domani, 20:30" · "Giovedì, 20:30" · "Sab 14 nov, 18:00" */
export function etichettaDataOra(d) {
  d = new Date(d)
  const oggi = inizioGiorno(new Date())
  const giorno = inizioGiorno(d)
  const diff = Math.round((giorno - oggi) / 86400000)
  let testo
  if (diff === 0) testo = 'Oggi'
  else if (diff === 1) testo = 'Domani'
  else if (diff === -1) testo = 'Ieri'
  else if (diff > 1 && diff < 7) testo = GIORNI[d.getDay()]
  else testo = `${GIORNI_BREVI[d.getDay()].charAt(0)}${GIORNI_BREVI[d.getDay()].slice(1).toLowerCase()} ${d.getDate()} ${MESI_BREVI[d.getMonth()]}`
  return `${testo}, ${ora(d)}`
}

/** "Stasera, 21:00" per la card grande della home */
export function etichettaProssima(d) {
  d = new Date(d)
  const base = etichettaDataOra(d)
  if (base.startsWith('Oggi') && d.getHours() >= 18) return base.replace('Oggi', 'Stasera')
  return base
}

export function dataEstesa(d = new Date()) {
  d = new Date(d)
  return `${GIORNI[d.getDay()]} ${d.getDate()} ${MESI[d.getMonth()]}`
}

export function giornoBreve(d) { return GIORNI_BREVI[new Date(d).getDay()] }
export function giornoNumero(d) { return new Date(d).getDate() }

export function euro(n) {
  n = Number(n || 0)
  if (n === 0) return 'Gratis'
  return `${n.toLocaleString('it-IT', { minimumFractionDigits: 0, maximumFractionDigits: 2 })} € a testa`
}

export function km(d) {
  if (d == null) return ''
  return d < 10 ? `${d.toFixed(1).replace('.', ',')} km` : `${Math.round(d)} km`
}

export function nomeBreve(p) {
  if (!p?.nome) return 'Giocatore'
  const parti = p.nome.trim().split(/\s+/)
  return parti.length > 1 ? `${parti[0]} ${parti[1][0]}.` : parti[0]
}

export function iniziali(p) {
  if (p?.iniziali) return p.iniziali
  if (!p?.nome) return '?'
  return p.nome.trim().split(/\s+/).slice(0, 2).map((x) => x[0].toUpperCase()).join('')
}

/** Testo del chip posti: "Manca 1 portiere" · "2 posti" · "Al completo" */
export function chipPosti(posizioni) {
  const liberi = posizioni.filter((p) => p.stato === 'libera' && p.ruolo !== 'panchina')
  if (liberi.length === 0) return { testo: 'Al completo', classe: 'neutro' }
  const portieri = liberi.filter((p) => p.ruolo === 'portiere').length
  if (portieri === liberi.length) return { testo: portieri === 1 ? 'Manca 1 portiere' : `Mancano ${portieri} portieri`, classe: 'avviso' }
  if (liberi.length === 1) return { testo: `1 posto · ${etichettaRuolo(liberi[0].ruolo).toLowerCase()}`, classe: 'avviso' }
  return { testo: `${liberi.length} posti`, classe: 'avviso' }
}

export function chipPostiDaConteggio(postiLiberi, ruoliLiberi = []) {
  if (!postiLiberi) return { testo: 'Al completo', classe: 'neutro' }
  if (ruoliLiberi.length === 1 && ruoliLiberi[0] === 'portiere') return { testo: postiLiberi === 1 ? 'Portiere' : `${postiLiberi} portieri`, classe: 'avviso' }
  return { testo: postiLiberi === 1 ? '1 posto' : `${postiLiberi} posti`, classe: 'avviso' }
}

/** Valore per <input type="datetime-local"> dalla data (ora locale) */
export function perInputDataOra(d) {
  d = new Date(d)
  const p = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`
}
