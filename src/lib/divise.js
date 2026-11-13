// Colori delle divise (stessa lista del database: colori_divise / nome_colore)
export const COLORI = {
  bianco: { hex: '#FFFFFF', f: 'bianca', p: 'bianchi' },
  nero: { hex: '#1C1C1C', f: 'nera', p: 'neri' },
  grigio: { hex: '#9AA3A0', f: 'grigia', p: 'grigi' },
  rosso: { hex: '#D32F2F', f: 'rossa', p: 'rossi' },
  granata: { hex: '#7B1E2B', f: 'granata', p: 'granata' },
  arancione: { hex: '#F57C00', f: 'arancione', p: 'arancioni' },
  giallo: { hex: '#FBC02D', f: 'gialla', p: 'gialli' },
  verde: { hex: '#2E7D32', f: 'verde', p: 'verdi' },
  azzurro: { hex: '#4FC3F7', f: 'azzurra', p: 'azzurri' },
  blu: { hex: '#1E3A8A', f: 'blu', p: 'blu' },
  viola: { hex: '#6A1B9A', f: 'viola', p: 'viola' },
  rosa: { hex: '#EC407A', f: 'rosa', p: 'rosa' }
}

export const DIVISE_PREDEFINITE = { A: { maglia: 'bianco', pantaloncini: 'nero' }, B: { maglia: 'blu', pantaloncini: 'blu' } }

export function divisaDi(partita, squadra) {
  return partita?.divise?.[squadra] ?? DIVISE_PREDEFINITE[squadra]
}
export function hex(colore) { return COLORI[colore]?.hex ?? '#FFFFFF' }
export function testoMaglia(d) { return `maglia ${COLORI[d.maglia]?.f ?? d.maglia}` }
export function testoDivisa(d) {
  return `maglia ${COLORI[d.maglia]?.f ?? d.maglia} e pantaloncini ${COLORI[d.pantaloncini]?.p ?? d.pantaloncini}`
}
export function testoPorta(d) {
  return `Porta la maglia ${COLORI[d.maglia]?.f ?? d.maglia} e i pantaloncini ${COLORI[d.pantaloncini]?.p ?? d.pantaloncini}`
}
