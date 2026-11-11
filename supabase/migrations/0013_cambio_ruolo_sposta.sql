-- =====================================================================
-- Cambio di ruolo coerente con "i cerchi stanno fermi, si spostano i giocatori":
-- il giocatore va su un cerchio LIBERO di quel ruolo nella sua squadra;
-- se non c'è, il suo cerchio diventa del nuovo ruolo e si sposta nella fascia giusta.
-- Rieseguibile.
-- =====================================================================
create or replace function public.altezza_ruolo(p_ruolo text)
returns smallint language sql immutable as $$
  select case p_ruolo when 'portiere' then 8 when 'difesa' then 34 when 'centro' then 60 when 'attacco' then 86 else 0 end::smallint;
$$;

-- esegue il cambio: ritorna l'id del posto dove finisce il giocatore
create or replace function public.applica_cambio_ruolo(p_posizione uuid, p_ruolo text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype; v_libero uuid;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  select id into v_libero from public.posizioni
  where partita_id = v_pos.partita_id and squadra = v_pos.squadra and ruolo = p_ruolo and stato = 'libera' and id <> p_posizione
  order by x limit 1;
  if v_libero is not null then
    update public.posizioni set giocatore_id = null, stato = 'libera', nuovo_ruolo_proposto = null where id = p_posizione;
    update public.posizioni set giocatore_id = v_pos.giocatore_id, stato = 'occupata', nuovo_ruolo_proposto = null where id = v_libero;
    return v_libero;
  end if;
  update public.posizioni
  set ruolo = p_ruolo, stato = case when giocatore_id is null then 'libera' else 'occupata' end, nuovo_ruolo_proposto = null,
      y = case when manuale then public.altezza_ruolo(p_ruolo) else y end
  where id = p_posizione;
  return p_posizione;
end $$;

create or replace function public.proponi_cambio(p_posizione uuid, p_nuovo_ruolo text)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype; v_modalita text;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.puo_gestire_squadra(v_pos.partita_id, v_pos.squadra) then raise exception 'Puoi cambiare solo i ruoli della squadra che gestisci'; end if;
  if v_pos.ruolo = p_nuovo_ruolo then raise exception 'È già quel ruolo'; end if;
  select modalita into v_modalita from public.partite where id = v_pos.partita_id;

  -- posto libero: cambia il ruolo del cerchio (è una scelta di schema)
  if v_pos.giocatore_id is null then
    update public.posizioni set ruolo = p_nuovo_ruolo, y = case when manuale then public.altezza_ruolo(p_nuovo_ruolo) else y end where id = p_posizione;
    return;
  end if;

  if v_pos.giocatore_id = auth.uid() or v_modalita = 'approvazione' then
    perform public.applica_cambio_ruolo(p_posizione, p_nuovo_ruolo);
    if v_pos.giocatore_id <> auth.uid() then
      perform public.messaggio_sistema(v_pos.partita_id, public.nome_breve(v_pos.giocatore_id) || ' ora gioca ' || public.etichetta_ruolo(p_nuovo_ruolo));
    end if;
    return;
  end if;

  update public.posizioni set stato = 'cambio_proposto', nuovo_ruolo_proposto = p_nuovo_ruolo where id = p_posizione;
  perform public.messaggio_sistema(v_pos.partita_id,
    'Proposta a ' || public.nome_breve(v_pos.giocatore_id) || ': passare a ' || public.etichetta_ruolo(p_nuovo_ruolo), 'cambio_ruolo', p_posizione);
end $$;

create or replace function public.rispondi_cambio(p_posizione uuid, p_accetta boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null or v_pos.giocatore_id <> auth.uid() then raise exception 'Non è il tuo posto'; end if;
  if v_pos.stato <> 'cambio_proposto' then raise exception 'Nessun cambio da confermare'; end if;
  if p_accetta then
    perform public.applica_cambio_ruolo(p_posizione, v_pos.nuovo_ruolo_proposto);
    perform public.messaggio_sistema(v_pos.partita_id, public.nome_breve(auth.uid()) || ' ha accettato: ora gioca ' || public.etichetta_ruolo(v_pos.nuovo_ruolo_proposto));
  else
    update public.posizioni set stato = 'occupata', nuovo_ruolo_proposto = null where id = p_posizione;
    perform public.messaggio_sistema(v_pos.partita_id, public.nome_breve(auth.uid()) || ' preferisce restare ' || public.etichetta_ruolo(v_pos.ruolo));
  end if;
end $$;
