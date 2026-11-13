// "Installa l'app": su Android e computer il browser offre l'installazione (evento beforeinstallprompt),
// su iPhone/iPad si fa a mano da Safari (Condividi → Aggiungi alla schermata Home).
export const installa = $state({ possibile: false, installata: false, ios: false })

let evento = null

export function avviaInstalla() {
  if (typeof window === 'undefined') return
  installa.ios = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
  installa.installata = window.matchMedia?.('(display-mode: standalone)').matches || navigator.standalone === true
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault()
    evento = e
    installa.possibile = true
  })
  window.addEventListener('appinstalled', () => {
    installa.installata = true
    installa.possibile = false
    evento = null
  })
}

/** Apre la finestra di installazione del browser. Restituisce true se l'utente ha accettato. */
export async function installaOra() {
  if (!evento) return false
  evento.prompt()
  const { outcome } = await evento.userChoice
  evento = null
  installa.possibile = false
  return outcome === 'accepted'
}
