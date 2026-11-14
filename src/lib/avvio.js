// Le richieste di permesso del telefono (posizione, notifiche) aspettano la fine del video di apertura,
// così non lo coprono. Se il video non c'è, si parte subito.
let segna
const finito = new Promise((r) => { segna = r })
let gia = false

export function avvioFinito() { if (!gia) { gia = true; segna() } }
export function dopoAvvio() { return finito }
