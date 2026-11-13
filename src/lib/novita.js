// Novità mostrate in un riquadro alla prima apertura dopo un aggiornamento.
// Claude aggiunge una voce IN CIMA a ogni "unisci" che porta qualcosa di visibile agli utenti.
// "id" deve essere unico e crescente (data + lettera). Testi brevi, per i giocatori.
export const NOVITA = [
  {
    id: '2026-11-13b',
    titolo: 'Novità: trova chi manca',
    punti: [
      'Nella partita: "Cerca chi manca" avvisa i giocatori vicini quando serve qualcuno',
      'Lo può usare chi gioca o è in tribuna, non solo l\'organizzatore',
      '"Cercami per le partite" è acceso: dalla Home scegli per quali ruoli e in che orari essere chiamato, o spegnilo'
    ]
  },
  {
    id: '2026-11-13a',
    titolo: 'Novità di Ne manca 1',
    punti: [
      'Numero dei messaggi da leggere sull\'icona Chat',
      'Divise: l\'organizzatore sceglie i colori, tu vedi cosa portare',
      'Aggiungi la tua foto dal Profilo (dalla fotocamera o dalla galleria)',
      'Amici: aggiungili e invitali alle partite, anche se non organizzi',
      'Mappa dei campi e ricerca entro i km che scegli',
      '"Cercami per le partite" in Home: fatti trovare quando manca un giocatore',
      'Puoi mettere l\'app sulla schermata Home del telefono'
    ]
  }
]

const CHIAVE = 'nm1-novita-viste'

export function ultimaVista() { try { return localStorage.getItem(CHIAVE) || '' } catch { return '' } }
export function segnaViste() { try { localStorage.setItem(CHIAVE, NOVITA[0]?.id ?? '') } catch {} }

/** Le novità non ancora viste (le più recenti per prime). */
export function novitaDaMostrare() {
  const vista = ultimaVista()
  return NOVITA.filter((n) => n.id > vista)
}
