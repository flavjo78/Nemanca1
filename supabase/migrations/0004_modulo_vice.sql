-- =====================================================================
-- Modulo scelto dall'organizzatore (es. 1-2-2), spostamenti/scambi di
-- giocatori, vice che possono gestire la formazione.
-- Rieseguibile.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Vice: chi può gestire la formazione oltre all'organizzatore
-- ---------------------------------------------------------------------
create table if not exists public.vice (
  partita_id uuid not null references public.partite(id) on delete cascade,
  giocatore_id uuid not null references public.profili(id) on delete cascade,
  creato_il timestamptz not null default now(),
  primary key (partita_id, giocatore_id)
);
alter table public.vice enable row level security;
drop policy if exists "vice leggibili" on public.vice;
create policy "vice leggibili" on public.vice for select to anon, authenticated using (true);
grant select on public.vice to anon, authenticated;

-- l'organizzatore "vero" (solo lui annulla la partita e nomina i vice)
create or replace function public.e_titolare(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.partite where id = p_partita and organizzatore_id = auth.uid());
$$;

-- da ora "organizzatore" nelle regole vuol dire: organizzatore o vice
create or replace function public.e_organizzatore(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.e_titolare(p_partita)
      or exists (select 1 from public.vice where partita_id = p_partita and giocatore_id = auth.uid());
$$;

create or replace function public.nomina_vice(p_partita uuid, p_giocatore uuid, p_si boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.e_titolare(p_partita) then raise exception 'Solo l''organizzatore può nominare un vice'; end if;
  if p_si then
    insert into public.vice (partita_id, giocatore_id) values (p_partita, p_giocatore) on conflict do nothing;
    perform public.messaggio_sistema(p_partita, public.nome_breve(p_giocatore) || ' ora può gestire la formazione');
  else
    delete from public.vice where partita_id = p_partita and giocatore_id = p_giocatore;
    perform public.messaggio_sistema(p_partita, public.nome_breve(p_giocatore) || ' non gestisce più la formazione');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Modulo: "1-2-2" → portiere 1, difesa 2, attacco 2
--          "1-1-2-1" → portiere 1, difesa 1, centro 2, attacco 1
-- ---------------------------------------------------------------------
create or replace function public.ruoli_da_modulo(p_modulo text)
returns table (ruolo text, quanti int) language plpgsql immutable as $$
declare v int[];
begin
  v := string_to_array(regexp_replace(p_modulo, '\s', '', 'g'), '-')::int[];
  if v is null or array_length(v, 1) not in (3, 4) or v[1] <> 1 then
    raise exception 'Modulo non valido: %', p_modulo;
  end if;
  ruolo := 'portiere'; quanti := 1; return next;
  ruolo := 'difesa'; quanti := v[2]; return next;
  if array_length(v, 1) = 4 then
    ruolo := 'centro'; quanti := v[3]; return next;
    ruolo := 'attacco'; quanti := v[4]; return next;
  else
    ruolo := 'centro'; quanti := 0; return next;
    ruolo := 'attacco'; quanti := v[3]; return next;
  end if;
end $$;

create or replace function public.modulo_predefinito(p_formato smallint)
returns text language sql immutable as $$
  select case p_formato when 5 then '1-2-2' when 8 then '1-3-3-1' else '1-4-4-2' end;
$$;

-- cambia il modulo di una squadra: chi è in campo resta in campo
create or replace function public.cambia_modulo(p_partita uuid, p_squadra char, p_modulo text)
returns void language plpgsql security definer set search_path = public as $$
declare
  r record;
  v_surplus uuid[] := '{}';
  v_mancano text[] := '{}';
  v_seat uuid;
  v_i int;
  v_pos public.posizioni%rowtype;
begin
  if not public.e_organizzatore(p_partita) then raise exception 'Solo chi gestisce la partita può cambiare il modulo'; end if;
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
end $$;

-- ---------------------------------------------------------------------
-- Spostare un giocatore su un altro posto (libero) o scambiarlo
-- ---------------------------------------------------------------------
create or replace function public.sposta_giocatore(p_da uuid, p_a uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_da public.posizioni%rowtype; v_a public.posizioni%rowtype;
begin
  select * into v_da from public.posizioni where id = p_da for update;
  select * into v_a from public.posizioni where id = p_a for update;
  if v_da.id is null or v_a.id is null or v_da.partita_id <> v_a.partita_id then raise exception 'Posti non validi'; end if;
  if not public.e_organizzatore(v_da.partita_id) then raise exception 'Solo chi gestisce la partita può spostare i giocatori'; end if;
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
end $$;

-- ---------------------------------------------------------------------
-- Creazione partita con modulo (anche diverso dal predefinito)
-- ---------------------------------------------------------------------
drop function if exists public.crea_partita(uuid, smallint, timestamptz, text, numeric, text, char, text, text, smallint);
create or replace function public.crea_partita(
  p_campo_id uuid,
  p_formato smallint,
  p_data_ora timestamptz,
  p_descrizione text default null,
  p_quota numeric default 0,
  p_sport text default 'calcio',
  p_squadra char default 'A',
  p_ruolo text default null,
  p_modalita text default 'libera',
  p_panchina smallint default 0,
  p_modulo text default null
) returns uuid language plpgsql security invoker set search_path = public as $$
declare
  v_id uuid;
  v_posto uuid;
  v_modulo text := coalesce(nullif(trim(p_modulo), ''), public.modulo_predefinito(p_formato));
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  if (select sum(quanti) from public.ruoli_da_modulo(v_modulo)) <> p_formato then
    raise exception 'Il modulo % non corrisponde al calcio a %', v_modulo, p_formato;
  end if;

  insert into public.partite (campo_id, organizzatore_id, sport, formato, data_ora, descrizione, quota, modalita, panchina)
  values (p_campo_id, auth.uid(), p_sport, p_formato, p_data_ora, p_descrizione, coalesce(p_quota, 0),
          coalesce(p_modalita, 'libera'), coalesce(p_panchina, 0))
  returning id into v_id;

  insert into public.posizioni (partita_id, squadra, ruolo, x, y)
  select v_id, s.squadra, t.ruolo, 50, 50
  from public.ruoli_da_modulo(v_modulo) t
  cross join generate_series(1, 11) g
  cross join (values ('A'), ('B')) as s(squadra)
  where g <= t.quanti;

  insert into public.posizioni (partita_id, squadra, ruolo, x, y)
  select v_id, s.squadra, 'panchina', 0, g
  from generate_series(1, coalesce(p_panchina, 0)) g
  cross join (values ('A'), ('B')) as s(squadra);

  if p_ruolo is not null then
    select id into v_posto from public.posizioni
    where partita_id = v_id and squadra = p_squadra and ruolo = p_ruolo and stato = 'libera'
    order by creato_il limit 1;
    if v_posto is null then
      select id into v_posto from public.posizioni
      where partita_id = v_id and squadra = p_squadra and stato = 'libera' and ruolo <> 'panchina'
      order by (ruolo = 'portiere'), creato_il limit 1;
    end if;
    if v_posto is not null then
      update public.posizioni set stato = 'occupata', giocatore_id = auth.uid() where id = v_posto;
    end if;
  end if;

  return v_id;
end $$;
grant execute on function public.crea_partita(uuid, smallint, timestamptz, text, numeric, text, char, text, text, smallint, text) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.vice;
exception when duplicate_object or undefined_object then null;
end $$;
