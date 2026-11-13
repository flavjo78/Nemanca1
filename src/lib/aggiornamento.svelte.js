// Se mentre l'app è aperta pubblichiamo una versione nuova, propone di ricaricare.
// Confronta il file principale della pagina caricata con quello pubblicato adesso.
export const aggiornamento = $state({ disponibile: false })

function scriptAttuale() {
  return document.querySelector('script[type="module"][src*="/assets/index-"]')?.getAttribute('src') ?? null
}

async function controlla() {
  const mio = scriptAttuale()
  if (!mio) return // in sviluppo
  try {
    const html = await (await fetch('/', { cache: 'no-store' })).text()
    const pubblicato = /\/assets\/index-[^"']+\.js/.exec(html)?.[0]
    if (pubblicato && pubblicato !== mio) aggiornamento.disponibile = true
  } catch { /* senza rete: niente */ }
}

export function avviaControlloAggiornamenti() {
  if (typeof document === 'undefined') return
  document.addEventListener('visibilitychange', () => { if (!document.hidden) controlla() })
  setInterval(controlla, 15 * 60 * 1000)
}

export function ricarica() { location.reload() }
