// Ultimo messaggio letto per partita, salvato sul dispositivo (per i pallini "nuovo")
const chiave = (id) => `nm1_letto_${id}`
export function segnaLetto(partitaId, quando) {
  try { localStorage.setItem(chiave(partitaId), new Date(quando ?? Date.now()).toISOString()) } catch { /* niente */ }
}
export function ultimoLetto(partitaId) {
  try { return localStorage.getItem(chiave(partitaId)) } catch { return null }
}
export function haNuovi(partitaId, ultimoIl) {
  if (!ultimoIl) return false
  const letto = ultimoLetto(partitaId)
  return !letto || new Date(ultimoIl) > new Date(letto)
}
