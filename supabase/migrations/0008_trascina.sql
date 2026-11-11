-- =====================================================================
-- Formazione trascinando i cerchi: posizione libera nella metà campo,
-- ruolo dedotto dall'altezza (vicino alla propria porta = difesa,
-- in mezzo = centrocampo, verso la metà campo = attacco). Rieseguibile.
-- =====================================================================
alter table public.posizioni add column if not exists manuale boolean not null default false;

-- y: 0 = propria porta, 100 = linea di metà campo
create or replace function public.ruolo_da_altezza(p_y numeric)
returns text language sql immutable as $$
  select case when p_y < 47 then 'difesa' when p_y < 73 then 'centro' else 'attacco' end;
$$;

create or replace function public.trascina_posto(p_posizione uuid, p_x numeric, p_y numeric)
returns text language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype; v_ruolo text; v_x smallint; v_y smallint;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.puo_gestire_squadra(v_pos.partita_id, v_pos.squadra) then raise exception 'Puoi spostare solo i posti della squadra che gestisci'; end if;
  if not public.partita_modificabile(v_pos.partita_id) then raise exception 'La partita non si può più modificare'; end if;
  if v_pos.ruolo = 'panchina' then raise exception 'La panchina non si trascina sul campo: usa "Sposta in un altro posto"'; end if;

  v_x := greatest(6, least(94, round(p_x)));
  if v_pos.ruolo = 'portiere' then
    v_y := v_pos.y; v_ruolo := 'portiere';   -- il portiere resta in porta, si sposta solo di lato
    v_x := greatest(30, least(70, v_x));
  else
    v_y := greatest(20, least(96, round(p_y)));
    v_ruolo := public.ruolo_da_altezza(v_y);
  end if;

  update public.posizioni
  set x = v_x, y = case when v_pos.ruolo = 'portiere' then 8 else v_y end, manuale = true,
      ruolo = v_ruolo,
      stato = case when giocatore_id is null then 'libera' else 'occupata' end,
      nuovo_ruolo_proposto = null
  where id = p_posizione;

  -- quando un cerchio diventa "a mano", anche gli altri della squadra si fissano dove sono
  -- (così non si rimescolano): il client manda le loro coordinate con fissa_posti

  if v_ruolo <> v_pos.ruolo and v_pos.giocatore_id is not null then
    perform public.messaggio_sistema(v_pos.partita_id, public.nome_breve(v_pos.giocatore_id) || ' ora gioca ' || public.etichetta_ruolo(v_ruolo));
  end if;
  return v_ruolo;
end $$;

-- fissa in un colpo le coordinate attuali (come le vede il client) di tutti i posti di una squadra
create or replace function public.fissa_posti(p_partita uuid, p_squadra char, p_coordinate jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if not public.puo_gestire_squadra(p_partita, p_squadra) then raise exception 'Puoi modificare solo la squadra che gestisci'; end if;
  for r in select key::uuid as id, (value->>'x')::numeric as x, (value->>'y')::numeric as y from jsonb_each(p_coordinate) loop
    update public.posizioni set x = round(r.x), y = round(r.y), manuale = true
    where id = r.id and partita_id = p_partita and squadra = p_squadra and ruolo <> 'panchina' and not manuale;
  end loop;
end $$;

-- cambiando il modulo con i contatori la squadra torna allo schieramento automatico
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

  update public.posizioni set manuale = false where partita_id = p_partita and squadra = p_squadra;
  perform public.messaggio_sistema(p_partita, 'Squadra ' || p_squadra || ': nuovo modulo ' || public.testo_modulo(p_modulo));
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
  values (p_partita, p_squadra, p_ruolo, 50, case p_ruolo when 'portiere' then 8 when 'difesa' then 34 when 'centro' then 60 when 'attacco' then 86 else 0 end)
  returning id into v_id;
  return v_id;
end $function$

;
