// Prova dell'app: simula Supabase con risposte finte, apre le schermate principali a 390px,
// le fotografa e fallisce se compare un errore JavaScript. Lanciata da scripts/prova-app.sh.
const { chromium } = require('playwright')
const path = require('path')
const fs = require('fs')
const OUT = process.env.CARTELLA_FOTO || path.join(__dirname, 'foto')
fs.mkdirSync(OUT, { recursive: true })
const UID = '11111111-1111-1111-1111-111111111111'
const CAMPO = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
const PARTITA = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
const PARTITA2 = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
const oggi = new Date(); oggi.setHours(21, 0, 0, 0)
const giovedi = new Date(Date.now() + 2 * 86400000); giovedi.setHours(20, 30, 0, 0)
const io = { id: UID, nome: 'Marco Rizzo', iniziali: 'MR', comune: 'Galatina', lat: 40.17, lng: 18.17, ruoli_preferiti: ['attacco'], creato_il: '2026-01-01' }
const campo = { id: CAMPO, nome: 'Campo San Rocco', indirizzo: 'Via dei Pini 12, Galatina', lat: 40.17, lng: 18.17, sport: ['calcio'], verificato: true, sponsor_nome: 'Bar Centrale', sponsor_testo: 'Terzo tempo offerto da Bar Centrale', creato_da: UID }
const nomi = [['Giulia P','GP'],['Luca C','LC'],['Anna D','AD'],['Marco Rizzo','MR'],['Fabio S','FS'],['Dario N','DN'],['Paolo L','PL'],['Sara T','ST'],['Rita B','RB']]
const schema5 = [['portiere',50,10],['difesa',30,40],['difesa',70,40],['attacco',30,75],['attacco',70,75]]
const posizioni = []
let k = 0
for (const sq of ['A','B']) for (const [ruolo,x,y] of schema5) {
  const libero = sq === 'B' && ruolo === 'portiere'
  const g = libero ? null : nomi[k++]
  posizioni.push({ id: `p${posizioni.length}`, partita_id: PARTITA, squadra: sq, ruolo, x, y,
    stato: libero ? 'libera' : (g[1] === 'RB' ? 'cambio_proposto' : 'occupata'),
    giocatore_id: g ? (g[1] === 'MR' ? UID : `u-${g[1]}`) : null,
    giocatore: g ? { id: g[1] === 'MR' ? UID : `u-${g[1]}`, nome: g[0], iniziali: g[1] } : null })
}
const partita = { id: PARTITA, campo_id: CAMPO, organizzatore_id: UID, sport: 'calcio', formato: 5, data_ora: oggi.toISOString(), descrizione: 'Partita tranquilla, livello medio.', quota: 6, stato: 'aperta', risultato_a: null, risultato_b: null,
  campo: { id: CAMPO, nome: campo.nome, indirizzo: campo.indirizzo }, organizzatore: io, posizioni }
const partita2 = { id: PARTITA2, campo_id: CAMPO, organizzatore_id: 'u-PL', formato: 8, data_ora: giovedi.toISOString(), quota: 5, stato: 'aperta',
  organizzatore: { id: 'u-PL', nome: 'Pino Lauro', iniziali: 'PL' }, campo: { id: CAMPO, nome: campo.nome },
  posizioni: Array.from({ length: 16 }, (_, i) => ({ id: `q${i}`, stato: i < 13 ? 'occupata' : 'libera', ruolo: i < 13 ? 'difesa' : 'centro', giocatore_id: i < 13 ? `z${i}` : null })) }

function rispondi(url, metodo) {
  const u = new URL(url)
  const p = u.pathname
  if (p.includes('/auth/v1/user')) return { user: { id: UID, email: 'marco@esempio.it', aud: 'authenticated', role: 'authenticated' } }
  if (p.includes('/auth/v1/token')) return { access_token: 'x', token_type: 'bearer', expires_in: 3600, refresh_token: 'y', user: { id: UID, email: 'marco@esempio.it' } }
  if (p.endsWith('/rpc/partite_vicine')) return [{ id: PARTITA2, campo_id: CAMPO, campo_nome: 'Sporting Club', organizzatore_id: 'u-PL', formato: 5, data_ora: giovedi.toISOString(), quota: 5, posti_liberi: 2, ruoli_liberi: ['centro','attacco'], distanza_km: 2.1 },
    { id: 'dddddddd-dddd-dddd-dddd-dddddddddddd', campo_id: CAMPO, campo_nome: 'Centro Sportivo Aradeo', organizzatore_id: 'u-PL', formato: 8, data_ora: new Date(Date.now()+4*86400000).toISOString(), quota: 5, posti_liberi: 1, ruoli_liberi: ['portiere'], distanza_km: 6.4 }]
  if (p.endsWith('/rpc/campi_vicini')) return [{ ...campo, distanza_km: 0.8, partite_aperte: 2 }, { id: 'c2', nome: 'Sporting Club', indirizzo: 'Via Roma 4, Galatina', distanza_km: 2.1, partite_aperte: 0, sport: ['calcio'] }]
  if (p.endsWith('/rpc/non_letti')) return [{ partita_id: PARTITA, quanti: 3 }]
  if (p.endsWith('/rpc/crea_partita')) return PARTITA
  const tabella = p.split('/rest/v1/')[1]
  const sel = u.searchParams.get('select') || ''
  switch (tabella) {
    case 'profili': return io
    case 'campi': return u.searchParams.get('id') ? campo : [campo]
    case 'posizioni': return [{ partita_id: PARTITA }]
    case 'richieste': return [{ id: 'r1', stato: 'in_attesa', ruolo_richiesto: 'portiere', giocatore: { id: 'u-LB', nome: 'Luca Bianchi', iniziali: 'LB' }, partita: { id: PARTITA, organizzatore_id: UID, data_ora: oggi.toISOString(), formato: 5 } }]
    case 'partite': {
      const id = (u.searchParams.get('id') || '').replace('eq.', '')
      if (id.startsWith('in.')) return [partita, partita2]
      if (id) return id === PARTITA2 ? partita2 : partita
      return [partita, partita2]
    }
    case 'profili_voti': return null
    case 'storico_partite': return []
  }
  return []
}

;(async () => {
  const browser = await chromium.launch()
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'it-IT' })
  const errori = []
  await ctx.route('**/finto.supabase.co/**', async (route) => {
    const req = route.request()
    const url = req.url()
    const corpo = rispondi(url, req.method())
    const intestazioni = { 'content-type': 'application/json', 'access-control-allow-origin': '*' }
    if (url.includes('head=true') || req.headers()['prefer']?.includes('count=exact')) intestazioni['content-range'] = '0-1/42'
    await route.fulfill({ status: 200, headers: intestazioni, body: JSON.stringify(corpo ?? null) })
  })
  // tessere della mappa: un quadrato vuoto, per non dipendere da internet
  const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64')
  await ctx.route('**/tile.openstreetmap.org/**', (r) => r.fulfill({ status: 200, headers: { 'content-type': 'image/png' }, body: PNG }))
  await ctx.route('**/nominatim.openstreetmap.org/**', (r) => r.fulfill({ status: 200, headers: { 'content-type': 'application/json' }, body: '[]' }))
  await ctx.route('**/fonts.googleapis.com/**', (r) => r.fulfill({ status: 200, headers: { 'content-type': 'text/css' }, body: '' }))

  // sessione salvata come la salva supabase-js
  const sessione = { access_token: 'x', token_type: 'bearer', expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: 'y', user: { id: UID, email: 'marco@esempio.it', aud: 'authenticated', role: 'authenticated', app_metadata: {}, user_metadata: {}, created_at: '2026-01-01' } }
  await ctx.addInitScript((s) => { if (window.__sessione !== false) localStorage.setItem('sb-finto-auth-token', JSON.stringify(s)) }, sessione)

  const page = await ctx.newPage()
  page.on('pageerror', (e) => errori.push('pageerror: ' + e.message))
  page.on('console', (m) => { if (m.type() === 'error') errori.push('console: ' + m.text()) })

  const foto = async (nome) => { await page.waitForTimeout(600); await page.screenshot({ path: `${OUT}/${nome}.png` }) }
  const base = process.env.INDIRIZZO_APP || 'http://localhost:4173'

  await page.goto(base + '/'); await page.waitForSelector('text=Ciao Marco', { timeout: 10000 }); await foto('home')
  await page.goto(base + `/campo/${CAMPO}?qr=1`); await page.waitForSelector('text=Campo San Rocco'); await foto('campo')
  await page.click('text=Organizza una partita su questo campo'); await page.waitForSelector('text=Formato'); await foto('nuova-partita')
  await page.goto(base + `/partita/${PARTITA}`); await page.waitForSelector('text=SQUADRA A'); await foto('partita')
  await page.goto(base + '/campi'); await page.waitForSelector('text=Campo San Rocco'); await foto('campi')
  await page.click('role=tab[name="Mappa"]'); await page.waitForSelector('.leaflet-container .pin'); await foto('campi-mappa')
  await page.click('.pin'); await page.waitForSelector('text=Apri il campo'); await foto('campi-mappa-popup')
  await page.click('role=tab[name="Lista"]')
  await page.goto(base + `/campo/${CAMPO}?nuovo=1`); await page.waitForSelector('img[alt^="QR code"]'); await foto('campo-qr')
  await page.goto(base + '/profilo'); await page.waitForSelector('text=Come ti valutano'); await foto('profilo')
  await page.goto(base + '/profilo/modifica'); await page.waitForSelector('text=Il tuo profilo'); await foto('profilo-modifica')
  await page.goto(base + '/'); await page.waitForSelector('text=Cercami per le partite'); await page.click('.chip-km'); await page.waitForSelector('text=Fino a quanti km vai a giocare?'); await page.click('.foglio >> text=30 km'); await foto('home-raggio')
  await page.goto(base + '/campi/nuovo'); await page.waitForSelector('text=Nome del campo'); await foto('nuovo-campo')

  // senza login: login e campo pubblico
  const ctx2 = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 })
  await ctx2.route('**/finto.supabase.co/**', (route) => route.fulfill({ status: 200, headers: { 'content-type': 'application/json' }, body: JSON.stringify(rispondi(route.request().url())) }))
  await ctx2.route('**/fonts.googleapis.com/**', (r) => r.fulfill({ status: 200, headers: { 'content-type': 'text/css' }, body: '' }))
  const p2 = await ctx2.newPage()
  p2.on('pageerror', (e) => errori.push('anon pageerror: ' + e.message))
  await p2.goto(base + '/'); await p2.waitForSelector('text=Mandami il codice'); await p2.waitForTimeout(500); await p2.screenshot({ path: `${OUT}/login.png` })
  await p2.goto(base + `/campo/${CAMPO}?qr=1`); await p2.waitForSelector('text=accedi con la tua email'); await p2.waitForTimeout(500); await p2.screenshot({ path: `${OUT}/campo-anonimo.png` })

  await browser.close()
  // il websocket del tempo reale verso il Supabase finto non può collegarsi: non è un errore dell'app
  const veri = errori.filter((e) => !/WebSocket connection to 'wss:\/\/finto\.supabase\.co/.test(e))
  console.log(veri.length ? 'ERRORI:\n' + veri.join('\n') : 'Nessun errore JS: tutte le schermate si aprono')
  if (veri.length) process.exit(1)
})().catch((e) => { console.error('FALLITO', e); process.exit(1) })
