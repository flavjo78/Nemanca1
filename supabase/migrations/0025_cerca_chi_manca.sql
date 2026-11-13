-- 0025: "Serve un portiere vicino a te". Rieseguibile.
-- Chi gioca o è in tribuna (o organizza) preme "Cerca chi manca": parte una notifica ai giocatori
-- con "Cercami" acceso, entro i km che hanno scelto, con il ruolo giusto (o "anche altri ruoli"),
-- nell'orario in cui vogliono riceverli. Precedenza a chi ha già giocato su quel campo.
-- Limiti: per ogni partita e ruolo un avviso ogni 2 ore; ogni giocatore al massimo
-- un avviso per partita e 3 al giorno; al massimo 30 giocatori per avviso.

alter table public.profili add column if not exists avvisi_ruoli text not null default 'miei';
alter table public.profili drop constraint if exists profili_avvisi_ruoli_valido;
alter table public.profili add constraint profili_avvisi_ruoli_valido check (avvisi_ruoli in ('miei', 'tutti'));
alter table public.profili add column if not exists avvisi_dalle smallint not null default 8;
alter table public.profili add column if not exists avvisi_alle smallint not null default 22;
alter table public.profili drop constraint if exists profili_avvisi_orario_valido;
alter table public.profili add constraint profili_avvisi_orario_valido
  check (avvisi_dalle between 0 and 23 and avvisi_alle between 1 and 24);

create table if not exists public.avvisi_cerca (
  id uuid primary key default gen_random_uuid(),
  partita_id uuid not null references public.partite(id) on delete cascade,
  ruolo text,
  da_id uuid references public.profili(id) on delete set null,
  avvisati int not null default 0,
  creato_il timestamptz not null default now()
);
alter table public.avvisi_cerca enable row level security;

create table if not exists public.avvisi_ricevuti (
  partita_id uuid not null references public.partite(id) on delete cascade,
  utente_id uuid not null references public.profili(id) on delete cascade,
  inviato_il timestamptz not null default now(),
  primary key (partita_id, utente_id)
);
alter table public.avvisi_ricevuti enable row level security;

-- l'ora attuale (Italia) rientra nella fascia scelta? (gestisce anche fasce a cavallo della mezzanotte)
create or replace function public.ora_ok(p_dalle smallint, p_alle smallint)
returns boolean language sql stable as $$
  select case
    when p_dalle < p_alle then extract(hour from now() at time zone 'Europe/Rome') >= p_dalle and extract(hour from now() at time zone 'Europe/Rome') < p_alle
    else extract(hour from now() at time zone 'Europe/Rome') >= p_dalle or extract(hour from now() at time zone 'Europe/Rome') < p_alle
  end;
$$;

create or replace function public.cerca_chi_manca(p_partita uuid, p_ruolo text default null)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_campo public.campi%rowtype;
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
  v_titolo := case v_ruolo when 'portiere' then 'Serve un portiere' when 'difesa' then 'Serve un difensore'
                           when 'centro' then 'Serve un centrocampista' when 'attacco' then 'Serve un attaccante'
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
      -- precedenza a chi ha già giocato su questo campo
      exists (select 1 from public.posizioni po join public.partite pa on pa.id = po.partita_id
              where po.giocatore_id = pr.id and pa.campo_id = v_campo.id) desc,
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
    public.nome_breve(auth.uid()) || ' cerca ' || case v_ruolo when 'portiere' then 'un portiere' when 'difesa' then 'un difensore'
      when 'centro' then 'un centrocampista' when 'attacco' then 'un attaccante' else 'un giocatore' end
    || ': ' || case when v_n = 0 then 'nessun giocatore disponibile in zona in questo momento'
                    when v_n = 1 then 'avvisato 1 giocatore vicino' else 'avvisati ' || v_n || ' giocatori vicini' end);
  return v_n;
end $$;
grant execute on function public.cerca_chi_manca(uuid, text) to authenticated;
