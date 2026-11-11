<script>
  import { onMount } from 'svelte'
  import { supabaseConfigurato } from './lib/supabase.js'
  import { router, abbina, gestisciClickLink, naviga } from './lib/router.svelte.js'
  import { auth, avviaAuth, profiloIncompleto } from './lib/auth.svelte.js'
  import Caricamento from './components/Caricamento.svelte'
  import Configurazione from './pages/Configurazione.svelte'
  import Login from './pages/Login.svelte'
  import CompletaProfilo from './pages/CompletaProfilo.svelte'
  import Home from './pages/Home.svelte'
  import Campi from './pages/Campi.svelte'
  import NuovoCampo from './pages/NuovoCampo.svelte'
  import Campo from './pages/Campo.svelte'
  import NuovaPartita from './pages/NuovaPartita.svelte'
  import Partita from './pages/Partita.svelte'
  import Chat from './pages/Chat.svelte'
  import Profilo from './pages/Profilo.svelte'
  import Admin from './pages/Admin.svelte'

  // privata = serve il login; pubblica = visibile anche dal QR senza account
  const rotte = [
    { pattern: '/', componente: Home, privata: true },
    { pattern: '/login', componente: Login },
    { pattern: '/campi', componente: Campi },
    { pattern: '/campi/nuovo', componente: NuovoCampo, privata: true },
    { pattern: '/campo/:id', componente: Campo },
    { pattern: '/campo/:id/nuova', componente: NuovaPartita, privata: true },
    { pattern: '/partita/:id', componente: Partita },
    { pattern: '/chat', componente: Chat, privata: true },
    { pattern: '/chat/:id', componente: Chat, privata: true },
    { pattern: '/profilo', componente: Profilo, privata: true },
    { pattern: '/profilo/modifica', componente: CompletaProfilo, privata: true },
    { pattern: '/admin', componente: Admin, privata: true }
  ]

  const corrente = $derived.by(() => {
    for (const r of rotte) {
      const parametri = abbina(r.pattern, router.percorso)
      if (parametri) return { ...r, parametri }
    }
    return null
  })

  onMount(() => { if (supabaseConfigurato) avviaAuth() })

  // Utente loggato sulla pagina di login → home
  $effect(() => {
    if (auth.pronto && auth.utente && router.percorso === '/login') {
      naviga(router.query.get('next') || '/', { sostituisci: true })
    }
  })
</script>

<svelte:document onclick={gestisciClickLink} />

<div class="cornice">
  {#if !supabaseConfigurato}
    <Configurazione />
  {:else if !auth.pronto}
    <Caricamento />
  {:else if !corrente}
    <div class="pagina"><div class="contenuto spazio-sopra"><div class="vuoto">Pagina non trovata.</div><a href="/" class="btn bianco">Torna alla home</a></div></div>
  {:else if corrente.privata && !auth.utente}
    <Login />
  {:else if auth.utente && profiloIncompleto() && corrente.pattern !== '/profilo/modifica'}
    <CompletaProfilo />
  {:else}
    {#key router.percorso}
      <corrente.componente {...corrente.parametri} />
    {/key}
  {/if}
</div>

<style>
  .cornice { max-width: 640px; margin: 0 auto; min-height: 100dvh; display: flex; flex-direction: column; }
</style>
