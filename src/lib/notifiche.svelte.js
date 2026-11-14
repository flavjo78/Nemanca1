import { naviga } from './router.svelte.js'
import { dopoAvvio } from './avvio.js'
// Notifiche push con OneSignal (web push).
// L'App ID è pubblico per design; si può cambiare con VITE_ONESIGNAL_APP_ID.
// OneSignal accetta un solo sito per app: le notifiche funzionano su www.nemanca1.com.

const APP_ID = import.meta.env.VITE_ONESIGNAL_APP_ID || '27506aa7-d2ae-4a62-8a47-56dad6193dd6'
export const ORIGINE_NOTIFICHE = 'https://www.nemanca1.com'

export const notifiche = $state({
  stato: 'sconosciuto', // non_supportate | altro_sito | installa_iphone | bloccate | spente | attive | sconosciuto
  occupato: false
})

let promessa = null

function iphone() {
  return /iPhone|iPad|iPod/.test(navigator.userAgent)
}
function installata() {
  return window.matchMedia?.('(display-mode: standalone)').matches || navigator.standalone === true
}

function statoIniziale() {
  if (typeof window === 'undefined') return 'non_supportate'
  if (location.origin !== ORIGINE_NOTIFICHE) return 'altro_sito'
  if (iphone() && !installata()) return 'installa_iphone'
  if (!('Notification' in window) || !('serviceWorker' in navigator) || !('PushManager' in window)) return 'non_supportate'
  return null
}

function apriDaNotifica(e) {
  try {
    const n = e?.notification ?? {}
    let percorso = n.additionalData?.percorso
    if (!percorso) {
      const url = e?.result?.url || n.launchURL
      if (url) { const u = new URL(url, location.origin); if (u.origin === location.origin) percorso = u.pathname + u.search }
    }
    if (percorso && percorso.startsWith('/') && percorso !== location.pathname + location.search) naviga(percorso)
  } catch { /* niente */ }
}

/** Carica l'SDK di OneSignal (una volta sola) e restituisce l'oggetto OneSignal. */
function carica() {
  if (promessa) return promessa
  promessa = new Promise((risolvi, rifiuta) => {
    window.OneSignalDeferred = window.OneSignalDeferred || []
    window.OneSignalDeferred.push(async (OneSignal) => {
      try {
        await OneSignal.init({ appId: APP_ID })
        OneSignal.User.PushSubscription.addEventListener('change', () => aggiorna(OneSignal))
        OneSignal.Notifications.addEventListener('permissionChange', () => aggiorna(OneSignal))
        // tocco su una notifica: apri la pagina giusta (su iPhone il telefono apre l'app ma non la pagina)
        OneSignal.Notifications.addEventListener('click', (e) => apriDaNotifica(e))
        risolvi(OneSignal)
      } catch (e) { rifiuta(e) }
    })
    const s = document.createElement('script')
    s.src = 'https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.page.js'
    s.defer = true
    s.onerror = () => rifiuta(new Error('OneSignal non raggiungibile'))
    document.head.appendChild(s)
  })
  return promessa
}

function aggiorna(OneSignal) {
  if (Notification.permission === 'denied') notifiche.stato = 'bloccate'
  else if (OneSignal.User.PushSubscription.optedIn) notifiche.stato = 'attive'
  else notifiche.stato = 'spente'
}

/** Da chiamare quando l'utente è entrato: collega il dispositivo al suo id. */
export async function avviaNotifiche(idUtente) {
  const s = statoIniziale()
  if (s) { notifiche.stato = s; return }
  try {
    const OneSignal = await carica()
    if (idUtente) await OneSignal.login(idUtente)
    aggiorna(OneSignal)
    // attive di default: a chi non ha ancora deciso proponiamo subito di attivarle
    setTimeout(proponiNotifiche, 2500)
  } catch (e) {
    console.warn('Notifiche:', e)
    notifiche.stato = 'non_supportate'
  }
}

/** All'uscita: il dispositivo non riceve più le notifiche di quell'utente. */
export async function scollegaNotifiche() {
  if (!promessa) return
  try { (await promessa).logout() } catch {}
}

/** Bottone "Attiva notifiche": chiede il permesso al browser e iscrive. */
export async function attivaNotifiche() {
  notifiche.occupato = true
  try {
    const OneSignal = await carica()
    if (Notification.permission !== 'granted') await OneSignal.Notifications.requestPermission()
    if (Notification.permission === 'granted') await OneSignal.User.PushSubscription.optIn()
    aggiorna(OneSignal)
  } finally {
    notifiche.occupato = false
  }
}

export async function disattivaNotifiche() {
  notifiche.occupato = true
  try {
    const OneSignal = await carica()
    await OneSignal.User.PushSubscription.optOut()
    aggiorna(OneSignal)
  } finally {
    notifiche.occupato = false
  }
}

const CHIAVE_PROPOSTA = 'nm1-notifiche-proposte'
const OGNI = 3 * 24 * 3600 * 1000 // se dice "Più tardi", si ripropone dopo 3 giorni

/** Le notifiche sono attive di default: chi non ha ancora deciso vede il riquadro "Attiva".
 *  Il browser chiede comunque il suo "Consenti" una volta (non si può saltare). */
export async function proponiNotifiche({ forza = false } = {}) {
  await dopoAvvio() // il riquadro delle notifiche arriva dopo il video d'apertura
  if (notifiche.stato !== 'spente' || Notification.permission !== 'default') return
  try {
    const ultima = Number(localStorage.getItem(CHIAVE_PROPOSTA) || 0)
    if (!forza && Date.now() - ultima < OGNI) return
    localStorage.setItem(CHIAVE_PROPOSTA, String(Date.now()))
  } catch {}
  try { (await carica()).Slidedown.promptPush({ force: true }) } catch {}
}
