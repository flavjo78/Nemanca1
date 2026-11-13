import { mount } from 'svelte'
import './app.css'
import App from './App.svelte'
import { avviaInstalla } from './lib/installa.svelte.js'
import { avviaControlloAggiornamenti } from './lib/aggiornamento.svelte.js'

avviaInstalla()
avviaControlloAggiornamenti()

const app = mount(App, { target: document.getElementById('app') })

export default app
