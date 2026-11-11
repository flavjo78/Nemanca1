-- =====================================================================
-- Se i posti li assegna l'organizzatore (modalità "approvazione"),
-- il cambio di ruolo è diretto: niente proposta da accettare.
-- Nella modalità "libera" resta la proposta che il giocatore accetta o rifiuta.
-- =====================================================================
create or replace function public.proponi_cambio(p_posizione uuid, p_nuovo_ruolo text)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype; v_modalita text;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.e_organizzatore(v_pos.partita_id) then raise exception 'Solo chi gestisce la partita può cambiare i ruoli'; end if;
  if v_pos.ruolo = p_nuovo_ruolo then raise exception 'È già quel ruolo'; end if;
  select modalita into v_modalita from public.partite where id = v_pos.partita_id;

  if v_pos.giocatore_id is null or v_pos.giocatore_id = auth.uid() or v_modalita = 'approvazione' then
    update public.posizioni set ruolo = p_nuovo_ruolo,
           stato = case when giocatore_id is null then 'libera' else 'occupata' end,
           nuovo_ruolo_proposto = null
    where id = p_posizione;
    if v_pos.giocatore_id is not null and v_pos.giocatore_id <> auth.uid() then
      perform public.messaggio_sistema(v_pos.partita_id,
        public.nome_breve(v_pos.giocatore_id) || ' ora gioca ' || public.etichetta_ruolo(p_nuovo_ruolo));
    end if;
    return;
  end if;

  update public.posizioni set stato = 'cambio_proposto', nuovo_ruolo_proposto = p_nuovo_ruolo where id = p_posizione;
  perform public.messaggio_sistema(v_pos.partita_id,
    'Proposta a ' || public.nome_breve(v_pos.giocatore_id) || ': passare a ' || public.etichetta_ruolo(p_nuovo_ruolo), 'cambio_ruolo', p_posizione);
end $$;
