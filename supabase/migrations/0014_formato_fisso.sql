-- =====================================================================
-- I giocatori in campo per squadra sono sempre quelli del formato
-- (calcio a 5 = 5, a 8 = 8, a 11 = 11, portiere compreso).
-- Si possono aggiungere/togliere solo posti in panchina; il modulo deve sommare giusto.
-- Rieseguibile.
-- =====================================================================
create or replace function public.formato_partita(p_partita uuid)
returns smallint language sql stable security definer set search_path = public as $$
  select formato from public.partite where id = p_partita;
$$;

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
  if (select sum(quanti) from public.ruoli_da_modulo(p_modulo)) <> public.formato_partita(p_partita) then
    raise exception 'Nel calcio a % il modulo deve avere % giocatori più il portiere', public.formato_partita(p_partita), public.formato_partita(p_partita) - 1;
  end if;

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
  elsif (select count(*) from public.posizioni where partita_id = p_partita and squadra = p_squadra and ruolo <> 'panchina') >= public.formato_partita(p_partita) then
    raise exception 'In campo ci sono già % giocatori: puoi aggiungere solo riserve in panchina', public.formato_partita(p_partita);
  end if;
  insert into public.posizioni (partita_id, squadra, ruolo, x, y)
  values (p_partita, p_squadra, p_ruolo, 50, case p_ruolo when 'portiere' then 8 when 'difesa' then 34 when 'centro' then 60 when 'attacco' then 86 else 0 end)
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
  if v_pos.ruolo <> 'panchina' and (select count(*) from public.posizioni where partita_id = v_pos.partita_id and squadra = v_pos.squadra and ruolo <> 'panchina') <= public.formato_partita(v_pos.partita_id) then
    raise exception 'In campo servono % giocatori: puoi togliere solo posti in panchina', public.formato_partita(v_pos.partita_id);
  end if;
  delete from public.posizioni where id = p_posizione;
end $function$

;

