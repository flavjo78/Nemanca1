-- =====================================================================
-- Modulo scritto senza portiere nei messaggi ("2-2", "1-2-1"). Rieseguibile.
-- =====================================================================
create or replace function public.testo_modulo(p_modulo text)
returns text language sql immutable as $$
  select case when coalesce((select quanti from public.ruoli_da_modulo(p_modulo) where ruolo = 'centro'), 0) = 0
    then (select quanti from public.ruoli_da_modulo(p_modulo) where ruolo = 'difesa') || '-' || (select quanti from public.ruoli_da_modulo(p_modulo) where ruolo = 'attacco')
    else (select quanti from public.ruoli_da_modulo(p_modulo) where ruolo = 'difesa') || '-' || (select quanti from public.ruoli_da_modulo(p_modulo) where ruolo = 'centro') || '-' || (select quanti from public.ruoli_da_modulo(p_modulo) where ruolo = 'attacco')
  end;
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

  perform public.messaggio_sistema(p_partita, 'Squadra ' || p_squadra || ': nuovo modulo ' || public.testo_modulo(p_modulo));
end $function$

;
