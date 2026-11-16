// Novità mostrate in un riquadro alla prima apertura dopo un aggiornamento.
// Claude aggiunge una voce IN CIMA a ogni "unisci" che porta qualcosa di visibile agli utenti.
// "id" deve essere unico e crescente (data + lettera). Testi brevi, per i giocatori.
export const NOVITA = [
  {
    id: '2026-11-16b',
    titolo: 'Novità: migliore in campo',
    punti: [
      'Quando crei una partita scegli anche la durata',
      'Puoi occupare un posto per un amico che non ha l\'app',
      'A fine partita votate il migliore in campo: chi vince riceve una coppa',
      'Dai i voti ai compagni: le medie compaiono nel profilo'
    ]
  },
  {
    id: '2026-11-16a',
    titolo: 'Novità: amici e liste',
    punti: [
      'Nella Chat ora trovi Partite, Amici e Liste',
      'Gli amici si aggiungono subito, senza conferma, e chi gioca con te diventa tuo amico da solo',
      'Crea liste di giocatori e invitale intere alle tue partite',
      'Chi viene invitato riceve anche un\'email con il link alla partita',
      'In Campi e Home scegli da dove contare i km: dal tuo comune o "da questa posizione"'
    ]
  },
  {
    id: '2026-11-14a',
    titolo: 'Novità: nuova apertura',
    punti: [
      'Un breve video di apertura accoglie chi apre l\'app (si può saltare)'
    ]
  },
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
