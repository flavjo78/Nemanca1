-- =====================================================================
-- Il vice è assegnato a una squadra: gestisce solo quella (come un capitano).
-- L'organizzatore gestisce entrambe. Rieseguibile.
-- =====================================================================
alter table public.vice add column if not exists squadra char(1);
update public.vice v set squadra = coalesce(
  (select p.squadra from public.posizioni p where p.partita_id = v.partita_id and p.giocatore_id = v.giocatore_id), 'A')
where squadra is null;
alter table public.vice alter column squadra set not null;
alter table public.vice drop constraint if exists vice_squadra_check;
alter table public.vice add constraint vice_squadra_check check (squadra in ('A','B'));

create or replace function public.puo_gestire_squadra(p_partita uuid, p_squadra char)
returns boolean language sql stable security definer set search_path = public as $$
  select public.e_titolare(p_partita)
      or exists (select 1 from public.vice where partita_id = p_partita and giocatore_id = auth.uid() and squadra = p_squadra);
$$;

drop function if exists public.nomina_vice(uuid, uuid, boolean);
create or replace function public.nomina_vice(p_partita uuid, p_giocatore uuid, p_squadra char, p_si boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.e_titolare(p_partita) then raise exception 'Solo l''organizzatore può nominare un vice'; end if;
  if p_si then
    insert into public.vice (partita_id, giocatore_id, squadra) values (p_partita, p_giocatore, p_squadra)
    on conflict (partita_id, giocatore_id) do update set squadra = excluded.squadra;
    perform public.messaggio_sistema(p_partita, public.nome_breve(p_giocatore) || ' è vice della squadra ' || p_squadra);
  else
    delete from public.vice where partita_id = p_partita and giocatore_id = p_giocatore;
    perform public.messaggio_sistema(p_partita, public.nome_breve(p_giocatore) || ' non è più vice');
  end if;
end $$;

-- le funzioni sul campo controllano la squadra del posto
CREATE OR REPLACE FUNCTION public.proponi_cambio(p_posizione uuid, p_nuovo_ruolo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_pos public.posizioni%rowtype; v_modalita text;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.puo_gestire_squadra(v_pos.partita_id, v_pos.squadra) then raise exception 'Solo chi gestisce la partita può cambiare i ruoli'; end if;
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
end $function$

;

CREATE OR REPLACE FUNCTION public.libera_posto(p_posizione uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_pos public.posizioni%rowtype;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.puo_gestire_squadra(v_pos.partita_id, v_pos.squadra) and not public.e_admin() then raise exception 'Solo l''organizzatore può farlo'; end if;
  if v_pos.giocatore_id is null then return; end if;
  perform public.messaggio_sistema(v_pos.partita_id, public.nome_breve(v_pos.giocatore_id) || ' è stato spostato in tribuna');
  insert into public.tribuna (partita_id, giocatore_id) values (v_pos.partita_id, v_pos.giocatore_id) on conflict do nothing;
  update public.posizioni set stato = 'libera', giocatore_id = null, nuovo_ruolo_proposto = null where id = p_posizione;
end $function$

;

CREATE OR REPLACE FUNCTION public.aggiungi_posto(p_partita uuid, p_squadra character, p_ruolo text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if not public.puo_gestire_squadra(p_partita, p_squadra) then raise exception 'Solo l''organizzatore può modificare lo schema'; end if;
  if not public.partita_modificabile(p_partita) then raise exception 'La partita non si può più modificare'; end if;
  if p_ruolo = 'panchina' then
    if (select count(*) from public.posizioni where partita_id = p_partita and squadra = p_squadra and ruolo = 'panchina') >= 7 then
      raise exception 'Una panchina può avere al massimo 7 riserve';
    end if;
  elsif (select count(*) from public.posizioni where partita_id = p_partita and squadra = p_squadra and ruolo <> 'panchina') >= 11 then
    raise exception 'Una squadra può avere al massimo 11 posti in campo';
  end if;
  insert into public.posizioni (partita_id, squadra, ruolo, x, y)
  values (p_partita, p_squadra, p_ruolo, 50, case p_ruolo when 'portiere' then 10 when 'difesa' then 36 when 'centro' then 58 when 'attacco' then 80 else 0 end)
  returning id into v_id;
  return v_id;
end $function$

;

CREATE OR REPLACE FUNCTION public.rimuovi_posto(p_posizione uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_pos public.posizioni%rowtype;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.puo_gestire_squadra(v_pos.partita_id, v_pos.squadra) then raise exception 'Solo l''organizzatore può modificare lo schema'; end if;
  if v_pos.giocatore_id is not null then raise exception 'Il posto è occupato: prima liberalo'; end if;
  if v_pos.ruolo <> 'panchina' and (select count(*) from public.posizioni where partita_id = v_pos.partita_id and squadra = v_pos.squadra and ruolo <> 'panchina') <= 1 then
    raise exception 'Ogni squadra deve avere almeno un posto in campo';
  end if;
  delete from public.posizioni where id = p_posizione;
end $function$

;

CREATE OR REPLACE FUNCTION public.chiedi_di_giocare(p_posizione uuid, p_giocatore uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_pos public.posizioni%rowtype;
begin
  select * into v_pos from public.posizioni where id = p_posizione;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.puo_gestire_squadra(v_pos.partita_id, v_pos.squadra) then raise exception 'Solo l''organizzatore può chiedere'; end if;
  if v_pos.stato <> 'libera' then raise exception 'Il posto non è più libero'; end if;
  if exists (select 1 from public.posizioni where partita_id = v_pos.partita_id and giocatore_id = p_giocatore) then raise exception 'È già in campo'; end if;
  insert into public.inviti (partita_id, da_id, a_id, posizione_id, stato, aggiornato_il)
  values (v_pos.partita_id, auth.uid(), p_giocatore, p_posizione, 'in_attesa', now())
  on conflict (partita_id, a_id) do update set posizione_id = excluded.posizione_id, stato = 'in_attesa', da_id = excluded.da_id, aggiornato_il = now();
  insert into public.tribuna (partita_id, giocatore_id) values (v_pos.partita_id, p_giocatore) on conflict do nothing;
  perform public.messaggio_sistema(v_pos.partita_id,
    'L''organizzatore chiede a ' || public.nome_breve(p_giocatore) || ' di giocare come ' || public.etichetta_ruolo(v_pos.ruolo) || ' (squadra ' || v_pos.squadra || ')');
end $function$

;

CREATE OR REPLACE FUNCTION public.cambia_modulo(p_partita uuid, p_squadra character, p_modulo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r record;
  v_surplus uuid[] := '{}';
  v_mancano text[] := '{}';
  v_seat uuid;
  v_i int;
  v_pos public.posizioni%rowtype;
begin
  if not public.puo_gestire_squadra(p_partita, p_squadra) then raise exception 'Puoi cambiare solo il modulo della squadra che gestisci'; end if;
  if not public.partita_modificabile(p_partita) then raise exception 'La partita non si può più modificare'; end if;

  for r in select t.ruolo, t.quanti,
                  (select count(*) from public.posizioni p where p.partita_id = p_partita and p.squadra = p_squadra and p.ruolo = t.ruolo)::int as ci_sono
           from public.ruoli_da_modulo(p_modulo) t
  loop
    if r.ci_sono > r.quanti then
      -- posti in più: si tengono quelli occupati, si liberano prima quelli vuoti
      v_surplus := v_surplus || array(
        select id from public.posizioni
        where partita_id = p_partita and squadra = p_squadra and ruolo = r.ruolo
        order by (giocatore_id is not null) asc, creato_il desc
        limit r.ci_sono - r.quanti);
    elsif r.ci_sono < r.quanti then
      for v_i in 1 .. (r.quanti - r.ci_sono) loop v_mancano := v_mancano || r.ruolo; end loop;
    end if;
  end loop;

  -- tra i posti in più, gli occupati vengono riusati per primi (il giocatore resta in campo)
  select array_agg(s order by (select giocatore_id is null from public.posizioni where id = s), s) into v_surplus
  from unnest(v_surplus) s;
  v_surplus := coalesce(v_surplus, '{}');

  v_i := 1;
  foreach v_seat in array v_surplus loop
    select * into v_pos from public.posizioni where id = v_seat;
    if v_i <= coalesce(array_length(v_mancano, 1), 0) then
      update public.posizioni set ruolo = v_mancano[v_i], stato = case when giocatore_id is null then 'libera' else 'occupata' end,
             nuovo_ruolo_proposto = null where id = v_seat;
      if v_pos.giocatore_id is not null then
        perform public.messaggio_sistema(p_partita, public.nome_breve(v_pos.giocatore_id) || ' passa a ' || public.etichetta_ruolo(v_mancano[v_i]) || ' (nuovo modulo)');
      end if;
      v_i := v_i + 1;
    elsif v_pos.giocatore_id is null then
      delete from public.posizioni where id = v_seat;
    else
      raise exception 'Il modulo % ha meno posti dei giocatori in campo nella squadra %: prima manda qualcuno in tribuna o in panchina', p_modulo, p_squadra;
    end if;
  end loop;

  -- ruoli che mancano ancora: nuovi posti liberi
  while v_i <= coalesce(array_length(v_mancano, 1), 0) loop
    insert into public.posizioni (partita_id, squadra, ruolo, x, y) values (p_partita, p_squadra, v_mancano[v_i], 50, 50);
    v_i := v_i + 1;
  end loop;

  perform public.messaggio_sistema(p_partita, 'Squadra ' || p_squadra || ': nuovo modulo ' || p_modulo);
end $function$

;

CREATE OR REPLACE FUNCTION public.sposta_giocatore(p_da uuid, p_a uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_da public.posizioni%rowtype; v_a public.posizioni%rowtype;
begin
  select * into v_da from public.posizioni where id = p_da for update;
  select * into v_a from public.posizioni where id = p_a for update;
  if v_da.id is null or v_a.id is null or v_da.partita_id <> v_a.partita_id then raise exception 'Posti non validi'; end if;
  if not (public.puo_gestire_squadra(v_da.partita_id, v_da.squadra) and public.puo_gestire_squadra(v_da.partita_id, v_a.squadra)) then raise exception 'Puoi spostare solo i giocatori della squadra che gestisci'; end if;
  if not public.partita_modificabile(v_da.partita_id) then raise exception 'La partita non si può più modificare'; end if;
  if v_da.giocatore_id is null then raise exception 'Il posto di partenza è vuoto'; end if;
  if p_da = p_a then return; end if;

  if v_a.giocatore_id is null then
    update public.posizioni set giocatore_id = null, stato = 'libera', nuovo_ruolo_proposto = null where id = p_da;
    update public.posizioni set giocatore_id = v_da.giocatore_id, stato = 'occupata', nuovo_ruolo_proposto = null where id = p_a;
    perform public.messaggio_sistema(v_da.partita_id, public.nome_breve(v_da.giocatore_id) || ' spostato: ' || public.etichetta_ruolo(v_a.ruolo) || ' (squadra ' || v_a.squadra || ')');
  else
    -- scambio: si libera prima un posto per rispettare l'unicità giocatore/partita
    update public.posizioni set giocatore_id = null where id = p_da;
    update public.posizioni set giocatore_id = v_da.giocatore_id, stato = 'occupata', nuovo_ruolo_proposto = null where id = p_a;
    update public.posizioni set giocatore_id = v_a.giocatore_id, stato = 'occupata', nuovo_ruolo_proposto = null where id = p_da;
    perform public.messaggio_sistema(v_da.partita_id, public.nome_breve(v_da.giocatore_id) || ' e ' || public.nome_breve(v_a.giocatore_id) || ' si scambiano il posto');
  end if;
end $function$

;

