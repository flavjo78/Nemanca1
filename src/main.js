import { mount } from 'svelte'
import './app.css'
import App from './App.svelte'
import { avviaInstalla } from './lib/installa.svelte.js'

avviaInstalla()

const app = mount(App, { target: document.getElementById('app') })

export default app
