// Router minimale basato sulla History API (niente dipendenze)
export const router = $state({
  percorso: window.location.pathname,
  query: new URLSearchParams(window.location.search)
})

function aggiorna() {
  router.percorso = window.location.pathname
  router.query = new URLSearchParams(window.location.search)
}

window.addEventListener('popstate', aggiorna)

/** Naviga a un percorso interno. */
export function naviga(destinazione, { sostituisci = false } = {}) {
  if (sostituisci) window.history.replaceState({}, '', destinazione)
  else window.history.pushState({}, '', destinazione)
  aggiorna()
  window.scrollTo(0, 0)
}

export function indietro(fallback = '/') {
  if (window.history.length > 1) window.history.back()
  else naviga(fallback, { sostituisci: true })
}

/** Intercetta i click sui link interni per non ricaricare la pagina. */
export function gestisciClickLink(evento) {
  const a = evento.target.closest('a')
  if (!a || a.target === '_blank' || a.hasAttribute('download')) return
  const href = a.getAttribute('href')
  if (!href || !href.startsWith('/') || href.startsWith('//')) return
  if (evento.metaKey || evento.ctrlKey || evento.shiftKey || evento.button !== 0) return
  evento.preventDefault()
  naviga(href)
}

/** Confronta un pattern tipo "/campo/:id" con un percorso; ritorna i parametri o null. */
export function abbina(pattern, percorso) {
  const p = pattern.split('/').filter(Boolean)
  const s = percorso.split('/').filter(Boolean)
  if (p.length !== s.length) return null
  const parametri = {}
  for (let i = 0; i < p.length; i++) {
    if (p[i].startsWith(':')) parametri[p[i].slice(1)] = decodeURIComponent(s[i])
    else if (p[i] !== s[i]) return null
  }
  return parametri
}
