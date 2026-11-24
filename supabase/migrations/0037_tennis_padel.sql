-- 0037: tennis e padel accanto al calcio.
-- Formato = giocatori per squadra: calcio 5/8/11, tennis e padel 1 (1 contro 1) o 2 (2 contro 2).
-- Ruoli facoltativi: nel 2 contro 2 l'organizzatore sceglie "destra e sinistra" oppure nessun ruolo ('singolo' = giocatore).
-- Niente modulo, divise, trascinamento e "migliore in campo" per tennis e padel; la panchina resta (di default nessuna).
-- Rieseguibile.

-- sport e formato coerenti
alter table public.partite drop constraint if exists partite_formato_check;
alter table public.partite drop constraint if exists partite_sport_formato;
alter table public.partite add constraint partite_sport_formato check (
  (sport = 'calcio' and formato in (5, 8, 11)) or (sport in ('tennis', 'padel') and formato in (1, 2)));

-- ruoli nuovi: singolo (giocatore), destra, sinistra
alter table public.posizioni drop constraint if exists posizioni_ruolo_check;
alter table public.posizioni add constraint posizioni_ruolo_check
  check (ruolo in ('portiere', 'difesa', 'centro', 'attacco', 'panchina', 'singolo', 'destra', 'sinistra'));
alter table public.posizioni drop constraint if exists posizioni_nuovo_ruolo_proposto_check;
alter table public.posizioni add constraint posizioni_nuovo_ruolo_proposto_check
  check (nuovo_ruolo_proposto in ('portiere', 'difesa', 'centro', 'attacco', 'panchina', 'singolo', 'destra', 'sinistra'));
alter table public.richieste drop constraint if exists richieste_ruolo_richiesto_check;
alter table public.richieste add constraint richieste_ruolo_richiesto_check
  check (ruolo_richiesto in ('portiere', 'difesa', 'centro', 'attacco', 'panchina', 'singolo', 'destra', 'sinistra'));

create or replace function public.etichetta_ruolo(p_ruolo text)
returns text language sql immutable as $$
  select case p_ruolo when 'portiere' then 'portiere' when 'difesa' then 'difensore'
                      when 'centro' then 'centrocampista' when 'attacco' then 'attaccante'
                      when 'panchina' then 'riserva in panchina'
                      when 'singolo' then 'giocatore' when 'destra' then 'giocatore di destra' when 'sinistra' then 'giocatore di sinistra'
                      else p_ruolo end;
$$;

create or replace function public.nome_sport(p_sport text)
returns text language sql immutable as $$
  select case p_sport when 'tennis' then 'tennis' when 'padel' then 'padel' else 'calcio' end;
$$;

-- crea partita: per tennis e padel i posti sono 1 o 2 per squadra (p_modulo = 'lati' per destra/sinistra nel 2 contro 2)
create or replace function public.crea_partita(p_campo_id uuid, p_formato smallint, p_data_ora timestamp with time zone,
  p_descrizione text default null, p_quota numeric default 0, p_sport text default 'calcio', p_squadra character default 'A',
  p_ruolo text default null, p_modalita text default 'libera', p_panchina smallint default 0, p_modulo text default null)
returns uuid language plpgsql set search_path to 'public' as $function$
declare
  v_id uuid;
  v_posto uuid;
  v_sport text := coalesce(nullif(p_sport, ''), 'calcio');
  v_racchetta boolean := coalesce(nullif(p_sport, ''), 'calcio') in ('tennis', 'padel');
  v_modulo text;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  if v_sport not in ('calcio', 'tennis', 'padel') then raise exception 'Sport non valido'; end if;
  if not exists (select 1 from public.campi where id = p_campo_id and v_sport = any(sport)) then
    raise exception 'Su questo campo non si gioca a %', public.nome_sport(v_sport);
  end if;
  if v_racchetta then
    if p_formato not in (1, 2) then raise exception 'Nel % si gioca 1 contro 1 o 2 contro 2', public.nome_sport(v_sport); end if;
  else
    v_modulo := coalesce(nullif(trim(p_modulo), ''), public.modulo_predefinito(p_formato));
    if (select sum(quanti) from public.ruoli_da_modulo(v_modulo)) <> p_formato then
      raise exception 'Il modulo % non corrisponde al calcio a %', v_modulo, p_formato;
    end if;
  end if;

  insert into public.partite (campo_id, organizzatore_id, sport, formato, data_ora, descrizione, quota, modalita, panchina)
  values (p_campo_id, auth.uid(), v_sport, p_formato, p_data_ora, p_descrizione, coalesce(p_quota, 0),
          coalesce(p_modalita, 'libera'), coalesce(p_panchina, 0))
  returning id into v_id;

  if v_racchetta then
    insert into public.posizioni (partita_id, squadra, ruolo, x, y)
    select v_id, s.squadra, r.ruolo, r.x, 60
    from (values ('A'), ('B')) as s(squadra)
    cross join lateral (
      select * from (values ('singolo', 50, 1)) v(ruolo, x, n) where p_formato = 1
      union all
      select * from (values ('destra', 30, 1), ('sinistra', 70, 2)) v(ruolo, x, n) where p_formato = 2 and p_modulo = 'lati'
      union all
      select * from (values ('singolo', 30, 1), ('singolo', 70, 2)) v(ruolo, x, n) where p_formato = 2 and coalesce(p_modulo, '') <> 'lati'
    ) r;
  else
    insert into public.posizioni (partita_id, squadra, ruolo, x, y)
    select v_id, s.squadra, t.ruolo, 50, 50
    from public.ruoli_da_modulo(v_modulo) t
    cross join generate_series(1, 11) g
    cross join (values ('A'), ('B')) as s(squadra)
    where g <= t.quanti;
  end if;

  insert into public.posizioni (partita_id, squadra, ruolo, x, y)
  select v_id, s.squadra, 'panchina', 0, g
  from generate_series(1, coalesce(p_panchina, 0)) g
  cross join (values ('A'), ('B')) as s(squadra);

  if p_ruolo is not null then
    select id into v_posto from public.posizioni
    where partita_id = v_id and squadra = p_squadra and ruolo = p_ruolo and stato = 'libera'
    order by creato_il, x limit 1;
    if v_posto is null then
      select id into v_posto from public.posizioni
      where partita_id = v_id and squadra = p_squadra and stato = 'libera' and ruolo <> 'panchina'
      order by (ruolo = 'portiere'), creato_il, x limit 1;
    end if;
    if v_posto is not null then
      update public.posizioni set stato = 'occupata', giocatore_id = auth.uid() where id = v_posto;
    end if;
  end if;

  return v_id;
end $function$;

-- partite vicine: filtro per sport (null = tutti) e sport nella risposta
drop function if exists public.partite_vicine(double precision, double precision, double precision, integer);
drop function if exists public.partite_vicine(double precision, double precision, double precision, integer, text);
create function public.partite_vicine(p_lat double precision, p_lng double precision, p_raggio_km double precision default 25,
  p_limite integer default 20, p_sport text default null)
returns table (id uuid, campo_id uuid, campo_nome text, campo_indirizzo text, organizzatore_id uuid, formato smallint,
  data_ora timestamptz, quota numeric, descrizione text, posti_liberi bigint, ruoli_liberi text[], distanza_km double precision, sport text)
language sql stable set search_path to 'public' as $$
  select p.id, c.id, c.nome, c.indirizzo,
         p.organizzatore_id, p.formato, p.data_ora, p.quota, p.descrizione,
         count(po.id) filter (where po.stato = 'libera' and po.ruolo <> 'panchina') as posti_liberi,
         array_remove(array_agg(distinct po.ruolo) filter (where po.stato = 'libera' and po.ruolo <> 'panchina'), null) as ruoli_liberi,
         public.distanza_km(p_lat, p_lng, c.lat, c.lng) as distanza_km,
         p.sport
  from public.partite p
  join public.campi c on c.id = p.campo_id
  left join public.posizioni po on po.partita_id = p.id
  where p.stato = 'aperta' and p.data_ora > now()
    and (p_sport is null or p.sport = p_sport)
    and public.distanza_km(p_lat, p_lng, c.lat, c.lng) <= p_raggio_km
  group by p.id, c.id
  having count(po.id) filter (where po.stato = 'libera' and po.ruolo <> 'panchina') > 0
  order by p.data_ora
  limit p_limite;
$$;
grant execute on function public.partite_vicine(double precision, double precision, double precision, integer, text) to anon, authenticated;

-- campi vicini: solo i campi dello sport scelto, partite aperte di quello sport
drop function if exists public.campi_vicini(double precision, double precision, double precision, integer);
drop function if exists public.campi_vicini(double precision, double precision, double precision, integer, text);
create function public.campi_vicini(p_lat double precision, p_lng double precision, p_raggio_km double precision default 25,
  p_limite integer default 50, p_sport text default null)
returns table (id uuid, nome text, indirizzo text, lat double precision, lng double precision, sport text[], verificato boolean,
  distanza_km double precision, partite_aperte bigint)
language sql stable set search_path to 'public' as $$
  select c.id, c.nome, c.indirizzo, c.lat, c.lng, c.sport, c.verificato,
         public.distanza_km(p_lat, p_lng, c.lat, c.lng),
         (select count(*) from public.partite p
           where p.campo_id = c.id and p.stato = 'aperta' and p.data_ora > now() and (p_sport is null or p.sport = p_sport))
  from public.campi c
  where public.distanza_km(p_lat, p_lng, c.lat, c.lng) <= p_raggio_km
    and (p_sport is null or p_sport = any(c.sport))
  order by 8
  limit p_limite;
$$;
grant execute on function public.campi_vicini(double precision, double precision, double precision, integer, text) to anon, authenticated;

-- chat e partite passate: anche lo sport
drop function if exists public.mie_chat();
create function public.mie_chat()
returns table (partita_id uuid, data_ora timestamptz, formato smallint, stato text, campo_nome text, ultimo_testo text, ultimo_tipo text,
  ultimo_autore text, ultimo_il timestamptz, messaggi bigint, archiviata boolean, attiva boolean, sport text)
language sql stable security definer set search_path to 'public' as $$
  select p.id, p.data_ora, p.formato, p.stato, c.nome,
         m.testo, m.tipo, pr.nome, m.creato_il,
         (select count(*) from public.messaggi x where x.partita_id = p.id),
         p.archiviata,
         not p.archiviata,
         p.sport
  from public.partite p
  join public.campi c on c.id = p.campo_id
  left join lateral (
    select * from public.messaggi mm where mm.partita_id = p.id order by mm.creato_il desc limit 1
  ) m on true
  left join public.profili pr on pr.id = m.autore_id
  where auth.uid() is not null
    and (p.organizzatore_id = auth.uid()
      or exists (select 1 from public.posizioni po where po.partita_id = p.id and po.giocatore_id = auth.uid())
      or exists (select 1 from public.tribuna t where t.partita_id = p.id and t.giocatore_id = auth.uid())
      or exists (select 1 from public.vice v where v.partita_id = p.id and v.giocatore_id = auth.uid())
      or exists (select 1 from public.inviti i where i.partita_id = p.id and i.a_id = auth.uid() and i.stato = 'in_attesa'))
  order by (not p.archiviata) desc, coalesce(m.creato_il, p.creato_il) desc;
$$;
grant execute on function public.mie_chat() to authenticated;

drop function if exists public.mie_partite_passate(boolean);
create function public.mie_partite_passate(p_archiviate boolean)
returns table (partita_id uuid, data_ora timestamptz, formato smallint, stato text, campo_id uuid, campo_nome text,
  risultato_a smallint, risultato_b smallint, mio_ruolo text, mia_squadra character, giocatori bigint, in_tribuna bigint,
  organizzatore boolean, sport text)
language sql stable security definer set search_path to 'public' as $$
  select p.id, p.data_ora, p.formato, p.stato, c.id, c.nome,
         p.risultato_a::smallint, p.risultato_b::smallint,
         coalesce(mia.ruolo, case when exists (select 1 from public.tribuna t where t.partita_id = p.id and t.giocatore_id = auth.uid()) then 'tribuna' end),
         mia.squadra,
         (select count(*) from public.posizioni x where x.partita_id = p.id and x.giocatore_id is not null),
         (select count(*) from public.tribuna t where t.partita_id = p.id),
         p.organizzatore_id = auth.uid(),
         p.sport
  from public.partite p
  join public.campi c on c.id = p.campo_id
  left join lateral (
    select po.ruolo, po.squadra from public.posizioni po
    where po.partita_id = p.id and po.giocatore_id = auth.uid() limit 1
  ) mia on true
  where auth.uid() is not null
    and p.archiviata = p_archiviate
    and p.stato in ('giocata', 'annullata')
    and (p.organizzatore_id = auth.uid() or mia.ruolo is not null
      or exists (select 1 from public.tribuna t where t.partita_id = p.id and t.giocatore_id = auth.uid())
      or exists (select 1 from public.vice v where v.partita_id = p.id and v.giocatore_id = auth.uid()))
  order by p.data_ora desc
  limit 200;
$$;
grant execute on function public.mie_partite_passate(boolean) to authenticated;

-- "migliore in campo" e voti solo per il calcio
create or replace function public.voti_da_dare()
returns table (partita_id uuid, data_ora timestamptz, campo_nome text, formato smallint, candidati jsonb)
language sql stable security definer set search_path to 'public' as $$
  select p.id, p.data_ora, c.nome, p.formato,
         coalesce((select jsonb_agg(jsonb_build_object('id', pr.id, 'nome', pr.nome, 'iniziali', pr.iniziali, 'foto_url', pr.foto_url,
                                                       'squadra', po.squadra, 'ruolo', po.ruolo) order by po.squadra, pr.nome)
                   from public.posizioni po join public.profili pr on pr.id = po.giocatore_id
                   where po.partita_id = p.id), '[]'::jsonb)
  from public.partite p join public.campi c on c.id = p.campo_id
  where auth.uid() is not null
    and p.sport = 'calcio'
    and p.stato <> 'annullata'
    and now() >= public.fine_partita(p)
    and now() < public.fine_partita(p) + interval '24 hours'
    and p.mvp_stato is null
    and auth.uid() = any(public.votanti_partita(p.id))
    and exists (select 1 from public.posizioni po where po.partita_id = p.id and po.giocatore_id is not null)
    and not exists (select 1 from public.voti_mvp v where v.partita_id = p.id and v.votante_id = auth.uid())
  order by p.data_ora;
$$;

create or replace function public.aggiorna_stati_partite()
returns void language plpgsql security definer set search_path to 'public' as $function$
declare v_id uuid;
begin
  for v_id in
    update public.partite p set stato = 'giocata'
    where p.stato in ('aperta', 'completa') and now() >= public.fine_partita(p)
    returning p.id
  loop
    perform public.amici_dalla_partita(v_id);
  end loop;

  for v_id in
    select p.id from public.partite p
    where p.stato = 'giocata' and p.sport = 'calcio' and p.mvp_stato is null and now() >= public.fine_partita(p) + interval '24 hours'
  loop
    perform public.chiudi_votazione(v_id);
  end loop;

  update public.partite set archiviata = true, archiviata_il = now()
  where not archiviata and stato in ('giocata', 'annullata')
    and (data_ora at time zone 'Europe/Rome')::date < (now() at time zone 'Europe/Rome')::date;
end $function$;

-- "Cerca chi manca": nel tennis e nel padel cerca un giocatore (i ruoli del profilo sono del calcio)
create or replace function public.cerca_chi_manca(p_partita uuid, p_ruolo text default null)
returns integer language plpgsql security definer set search_path to 'public' as $function$
declare
  v_campo public.campi%rowtype;
  v_sport text;
  v_ruolo text := nullif(p_ruolo, 'qualsiasi');
  v_desc text;
  v_titolo text;
  r record;
  v_n int := 0;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  if not (public.e_organizzatore(p_partita)
          or exists (select 1 from public.posizioni where partita_id = p_partita and giocatore_id = auth.uid())
          or exists (select 1 from public.tribuna where partita_id = p_partita and giocatore_id = auth.uid())) then
    raise exception 'Può cercare giocatori solo chi gioca o è in tribuna in questa partita';
  end if;
  if not public.partita_modificabile(p_partita) then raise exception 'La partita non è più aperta'; end if;
  select sport into v_sport from public.partite where id = p_partita;
  if v_sport <> 'calcio' then v_ruolo := null; end if;
  if v_ruolo is not null and v_ruolo not in ('portiere', 'difesa', 'centro', 'attacco') then raise exception 'Ruolo non valido'; end if;
  if not exists (select 1 from public.posizioni where partita_id = p_partita and stato = 'libera' and ruolo <> 'panchina'
                 and (v_ruolo is null or ruolo = v_ruolo)) then
    raise exception 'In campo non ci sono posti liberi per questo ruolo';
  end if;
  if exists (select 1 from public.avvisi_cerca where partita_id = p_partita and ruolo is not distinct from v_ruolo
             and creato_il > now() - interval '2 hours') then
    raise exception 'L''avviso per questo ruolo è già partito da poco: riprova tra un paio d''ore o invita i tuoi amici';
  end if;

  select c.* into v_campo from public.campi c join public.partite p on p.campo_id = c.id where p.id = p_partita;
  v_desc := public.descrivi_partita(p_partita);
  v_titolo := case when v_sport <> 'calcio' then 'Serve un giocatore di ' || public.nome_sport(v_sport)
                   when v_ruolo = 'portiere' then 'Serve un portiere' when v_ruolo = 'difesa' then 'Serve un difensore'
                   when v_ruolo = 'centro' then 'Serve un centrocampista' when v_ruolo = 'attacco' then 'Serve un attaccante'
                   else 'Serve un giocatore' end;

  for r in
    select pr.id, public.distanza_km(pr.lat, pr.lng, v_campo.lat, v_campo.lng) as km
    from public.profili pr
    where pr.cercami and pr.lat is not null and pr.id <> auth.uid()
      and public.distanza_km(pr.lat, pr.lng, v_campo.lat, v_campo.lng) <= pr.raggio_km
      and (v_ruolo is null or pr.avvisi_ruoli = 'tutti' or coalesce(array_length(pr.ruoli_preferiti, 1), 0) = 0
           or v_ruolo = any(pr.ruoli_preferiti))
      and public.ora_ok(pr.avvisi_dalle, pr.avvisi_alle)
      and not exists (select 1 from public.posizioni po where po.partita_id = p_partita and po.giocatore_id = pr.id)
      and not exists (select 1 from public.partite pa where pa.id = p_partita and pa.organizzatore_id = pr.id)
      and not exists (select 1 from public.avvisi_ricevuti x where x.partita_id = p_partita and x.utente_id = pr.id)
      and (select count(*) from public.avvisi_ricevuti x where x.utente_id = pr.id
           and x.inviato_il > now() - interval '24 hours') < 3
    order by
      -- precedenza a chi ha già giocato su questo campo, poi a chi ha già giocato a questo sport
      exists (select 1 from public.posizioni po join public.partite pa on pa.id = po.partita_id
              where po.giocatore_id = pr.id and pa.campo_id = v_campo.id and pa.sport = v_sport) desc,
      exists (select 1 from public.posizioni po join public.partite pa on pa.id = po.partita_id
              where po.giocatore_id = pr.id and pa.sport = v_sport) desc,
      2
    limit 30
  loop
    insert into public.avvisi_ricevuti (partita_id, utente_id) values (p_partita, r.id) on conflict do nothing;
    perform public.invia_push(array[r.id], v_titolo,
      v_desc || ' · a ' || replace(to_char(round(r.km::numeric, 1), 'FM990.0'), '.', ',') || ' km da te. Tocca per entrare.',
      '/partita/' || p_partita, 'cerca-' || p_partita);
    v_n := v_n + 1;
  end loop;

  insert into public.avvisi_cerca (partita_id, ruolo, da_id, avvisati) values (p_partita, v_ruolo, auth.uid(), v_n);
  perform public.messaggio_sistema(p_partita,
    public.nome_breve(auth.uid()) || ' cerca ' || case when v_sport <> 'calcio' then 'un giocatore di ' || public.nome_sport(v_sport)
      when v_ruolo = 'portiere' then 'un portiere' when v_ruolo = 'difesa' then 'un difensore'
      when v_ruolo = 'centro' then 'un centrocampista' when v_ruolo = 'attacco' then 'un attaccante' else 'un giocatore' end
    || ': ' || case when v_n = 0 then 'nessun giocatore disponibile in zona in questo momento'
                    when v_n = 1 then 'avvisato 1 giocatore vicino' else 'avvisati ' || v_n || ' giocatori vicini' end);
  return v_n;
end $function$;

-- profilo separato per sport: storico con lo sport e voti per sport
create or replace view public.storico_partite with (security_invoker = true) as
 select po.giocatore_id,
    p.id as partita_id,
    p.data_ora,
    p.formato,
    p.stato,
    p.risultato_a,
    p.risultato_b,
    po.squadra,
    po.ruolo,
    c.id as campo_id,
    c.nome as campo_nome,
    case
      when p.stato <> 'giocata' or p.risultato_a is null then null::text
      when p.risultato_a = p.risultato_b then 'pareggio'::text
      when (po.squadra = 'A' and p.risultato_a > p.risultato_b) or (po.squadra = 'B' and p.risultato_b > p.risultato_a) then 'vinta'::text
      else 'persa'::text
    end as esito,
    p.sport
   from public.posizioni po
     join public.partite p on p.id = po.partita_id
     join public.campi c on c.id = p.campo_id
  where po.giocatore_id is not null;
grant select on public.storico_partite to authenticated;

create or replace view public.profili_voti_sport as
  select r.a_id as profilo_id, p.sport,
         count(*)::integer as n_recensioni,
         round(avg(r.puntualita), 1) as puntualita,
         round(avg(r.correttezza), 1) as correttezza,
         round(avg(r.livello), 1) as livello,
         round(avg(r.squadra), 1) as squadra,
         round((avg(r.puntualita) + avg(r.correttezza) + avg(r.livello) + avg(r.squadra)) / 4, 1) as complessivo
  from public.recensioni r join public.partite p on p.id = r.partita_id
  group by r.a_id, p.sport;
revoke all on public.profili_voti_sport from anon;
grant select on public.profili_voti_sport to authenticated;

-- l'amministratore sceglie gli sport di un campo (un circolo può avere calcetto, tennis e padel)
create or replace function public.admin_sport_campo(p_campo uuid, p_sport text[])
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  if coalesce(array_length(p_sport, 1), 0) = 0 or not (p_sport <@ array['calcio', 'tennis', 'padel']) then
    raise exception 'Scegli almeno uno sport tra calcio, tennis e padel';
  end if;
  update public.campi set sport = p_sport where id = p_campo;
end $$;
revoke execute on function public.admin_sport_campo(uuid, text[]) from public, anon;
grant execute on function public.admin_sport_campo(uuid, text[]) to authenticated;
