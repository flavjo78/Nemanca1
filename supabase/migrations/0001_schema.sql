-- =====================================================================
-- App calcetto – schema iniziale (Tappa 1, predisposto per le tappe 2-5)
-- Eseguire nell'editor SQL di Supabase (o con `supabase db push`).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Profili (1 riga per utente auth)
-- ---------------------------------------------------------------------
create table if not exists public.profili (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text,
  iniziali text,
  comune text,
  lat double precision,
  lng double precision,
  ruoli_preferiti text[] not null default '{}',
  creato_il timestamptz not null default now()
);

create or replace function public.calcola_iniziali(p_nome text)
returns text language sql immutable as $$
  select upper(left(coalesce(split_part(trim(p_nome), ' ', 1), ''), 1) ||
               left(coalesce(nullif(split_part(trim(p_nome), ' ', 2), ''), ''), 1));
$$;

create or replace function public.profili_prima_di_salvare()
returns trigger language plpgsql as $$
begin
  new.iniziali := nullif(public.calcola_iniziali(new.nome), '');
  return new;
end $$;

drop trigger if exists trg_profili_iniziali on public.profili;
create trigger trg_profili_iniziali
before insert or update of nome on public.profili
for each row execute function public.profili_prima_di_salvare();

-- Crea il profilo vuoto quando nasce un utente
create or replace function public.gestisci_nuovo_utente()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profili (id) values (new.id) on conflict do nothing;
  return new;
end $$;

drop trigger if exists trg_nuovo_utente on auth.users;
create trigger trg_nuovo_utente
after insert on auth.users
for each row execute function public.gestisci_nuovo_utente();

-- ---------------------------------------------------------------------
-- Campi
-- ---------------------------------------------------------------------
create table if not exists public.campi (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  indirizzo text not null,
  lat double precision not null,
  lng double precision not null,
  sport text[] not null default '{calcio}',
  verificato boolean not null default false,
  sponsor_nome text,
  sponsor_testo text,
  creato_da uuid references public.profili(id) on delete set null,
  creato_il timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Partite
-- ---------------------------------------------------------------------
create table if not exists public.partite (
  id uuid primary key default gen_random_uuid(),
  campo_id uuid not null references public.campi(id) on delete cascade,
  organizzatore_id uuid not null references public.profili(id) on delete cascade,
  sport text not null default 'calcio',
  formato smallint not null check (formato in (5, 8, 11)),
  data_ora timestamptz not null,
  descrizione text,
  quota numeric(6,2) not null default 0,
  stato text not null default 'aperta' check (stato in ('aperta','completa','giocata','annullata')),
  risultato_a smallint,
  risultato_b smallint,
  creato_il timestamptz not null default now()
);
create index if not exists partite_campo_data on public.partite (campo_id, data_ora);
create index if not exists partite_data on public.partite (data_ora);

-- ---------------------------------------------------------------------
-- Posizioni sul campo disegnato
-- x,y: percentuale 0-100 nella metà campo della squadra (y=0 porta propria)
-- ---------------------------------------------------------------------
create table if not exists public.posizioni (
  id uuid primary key default gen_random_uuid(),
  partita_id uuid not null references public.partite(id) on delete cascade,
  squadra char(1) not null check (squadra in ('A','B')),
  ruolo text not null check (ruolo in ('portiere','difesa','centro','attacco')),
  x smallint not null,
  y smallint not null,
  stato text not null default 'libera' check (stato in ('libera','occupata','cambio_proposto')),
  giocatore_id uuid references public.profili(id) on delete set null,
  nuovo_ruolo_proposto text check (nuovo_ruolo_proposto in ('portiere','difesa','centro','attacco')),
  creato_il timestamptz not null default now()
);
create index if not exists posizioni_partita on public.posizioni (partita_id);
create index if not exists posizioni_giocatore on public.posizioni (giocatore_id);
-- un giocatore occupa al massimo un posto per partita
create unique index if not exists posizioni_un_posto_per_giocatore
  on public.posizioni (partita_id, giocatore_id) where giocatore_id is not null;

-- ---------------------------------------------------------------------
-- Richieste di ingresso (stile BlaBlaCar)
-- ---------------------------------------------------------------------
create table if not exists public.richieste (
  id uuid primary key default gen_random_uuid(),
  partita_id uuid not null references public.partite(id) on delete cascade,
  giocatore_id uuid not null references public.profili(id) on delete cascade,
  ruolo_richiesto text check (ruolo_richiesto in ('portiere','difesa','centro','attacco')),
  stato text not null default 'in_attesa' check (stato in ('in_attesa','accettata','rifiutata')),
  creato_il timestamptz not null default now()
);
create unique index if not exists richieste_una_in_attesa
  on public.richieste (partita_id, giocatore_id) where stato = 'in_attesa';

-- ---------------------------------------------------------------------
-- Inviti
-- ---------------------------------------------------------------------
create table if not exists public.inviti (
  id uuid primary key default gen_random_uuid(),
  partita_id uuid not null references public.partite(id) on delete cascade,
  da_id uuid not null references public.profili(id) on delete cascade,
  a_id uuid not null references public.profili(id) on delete cascade,
  stato text not null default 'in_attesa' check (stato in ('in_attesa','accettato','rifiutato')),
  creato_il timestamptz not null default now(),
  unique (partita_id, a_id)
);

-- ---------------------------------------------------------------------
-- Messaggi (chat della partita)
-- ---------------------------------------------------------------------
create table if not exists public.messaggi (
  id uuid primary key default gen_random_uuid(),
  partita_id uuid not null references public.partite(id) on delete cascade,
  autore_id uuid references public.profili(id) on delete set null,
  testo text not null,
  tipo text not null default 'testo' check (tipo in ('testo','sistema','richiesta','cambio_ruolo')),
  riferimento_id uuid,
  creato_il timestamptz not null default now()
);
create index if not exists messaggi_partita on public.messaggi (partita_id, creato_il);

-- ---------------------------------------------------------------------
-- Recensioni (anonime: si legge solo la media dalla vista)
-- ---------------------------------------------------------------------
create table if not exists public.recensioni (
  id uuid primary key default gen_random_uuid(),
  partita_id uuid not null references public.partite(id) on delete cascade,
  da_id uuid not null references public.profili(id) on delete cascade,
  a_id uuid not null references public.profili(id) on delete cascade,
  puntualita smallint not null check (puntualita between 1 and 5),
  correttezza smallint not null check (correttezza between 1 and 5),
  livello smallint not null check (livello between 1 and 5),
  squadra smallint not null check (squadra between 1 and 5),
  creato_il timestamptz not null default now(),
  unique (partita_id, da_id, a_id),
  check (da_id <> a_id)
);

-- ---------------------------------------------------------------------
-- Prenotazioni (per il futuro)
-- ---------------------------------------------------------------------
create table if not exists public.prenotazioni (
  id uuid primary key default gen_random_uuid(),
  campo_id uuid not null references public.campi(id) on delete cascade,
  partita_id uuid references public.partite(id) on delete set null,
  inizio timestamptz not null,
  fine timestamptz not null,
  stato text not null default 'richiesta' check (stato in ('richiesta','confermata','annullata')),
  creato_il timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Funzioni di supporto
-- ---------------------------------------------------------------------
create or replace function public.distanza_km(lat1 double precision, lng1 double precision,
                                             lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  ));
$$;

-- vero se l'utente è organizzatore della partita
create or replace function public.e_organizzatore(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.partite where id = p_partita and organizzatore_id = auth.uid());
$$;

-- vero se l'utente partecipa (organizzatore o posto occupato)
create or replace function public.partecipa(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.e_organizzatore(p_partita)
      or exists (select 1 from public.posizioni
                 where partita_id = p_partita and giocatore_id = auth.uid());
$$;

-- schema predefinito dei posti per formato (ruolo, x, y) – uguale per le due squadre
create or replace function public.schema_predefinito(p_formato smallint)
returns table (ruolo text, x smallint, y smallint) language sql immutable as $$
  select v.ruolo, v.x::smallint, v.y::smallint from (values
    -- calcio a 5: 1-2-2
    ('portiere', 50, 10, 5), ('difesa', 30, 40, 5), ('difesa', 70, 40, 5),
    ('attacco', 30, 75, 5), ('attacco', 70, 75, 5),
    -- calcio a 8: 1-3-3-1
    ('portiere', 50, 10, 8), ('difesa', 22, 35, 8), ('difesa', 50, 32, 8), ('difesa', 78, 35, 8),
    ('centro', 22, 60, 8), ('centro', 50, 58, 8), ('centro', 78, 60, 8), ('attacco', 50, 84, 8),
    -- calcio a 11: 1-4-4-2
    ('portiere', 50, 8, 11), ('difesa', 15, 30, 11), ('difesa', 38, 27, 11), ('difesa', 62, 27, 11), ('difesa', 85, 30, 11),
    ('centro', 15, 55, 11), ('centro', 38, 52, 11), ('centro', 62, 52, 11), ('centro', 85, 55, 11),
    ('attacco', 36, 80, 11), ('attacco', 64, 80, 11)
  ) as v(ruolo, x, y, formato)
  where v.formato = p_formato;
$$;

-- crea la partita, i posti di entrambe le squadre e fa sedere l'organizzatore
create or replace function public.crea_partita(
  p_campo_id uuid,
  p_formato smallint,
  p_data_ora timestamptz,
  p_descrizione text default null,
  p_quota numeric default 0,
  p_sport text default 'calcio',
  p_squadra char default 'A',
  p_ruolo text default null
) returns uuid language plpgsql security invoker set search_path = public as $$
declare
  v_id uuid;
  v_posto uuid;
begin
  if auth.uid() is null then
    raise exception 'Devi essere autenticato';
  end if;

  insert into public.partite (campo_id, organizzatore_id, sport, formato, data_ora, descrizione, quota)
  values (p_campo_id, auth.uid(), p_sport, p_formato, p_data_ora, p_descrizione, coalesce(p_quota, 0))
  returning id into v_id;

  insert into public.posizioni (partita_id, squadra, ruolo, x, y)
  select v_id, s.squadra, sp.ruolo, sp.x, sp.y
  from public.schema_predefinito(p_formato) sp
  cross join (values ('A'), ('B')) as s(squadra);

  if p_ruolo is not null then
    select id into v_posto from public.posizioni
    where partita_id = v_id and squadra = p_squadra and ruolo = p_ruolo and stato = 'libera'
    order by x limit 1;
    if v_posto is not null then
      update public.posizioni set stato = 'occupata', giocatore_id = auth.uid() where id = v_posto;
    end if;
  end if;

  return v_id;
end $$;

-- partite aperte con posti liberi vicino a un punto
create or replace function public.partite_vicine(
  p_lat double precision,
  p_lng double precision,
  p_raggio_km double precision default 25,
  p_limite int default 20
) returns table (
  id uuid, campo_id uuid, campo_nome text, campo_indirizzo text,
  organizzatore_id uuid, formato smallint, data_ora timestamptz, quota numeric,
  descrizione text, posti_liberi bigint, ruoli_liberi text[], distanza_km double precision
) language sql stable security invoker set search_path = public as $$
  select p.id, c.id, c.nome, c.indirizzo,
         p.organizzatore_id, p.formato, p.data_ora, p.quota, p.descrizione,
         count(po.id) filter (where po.stato = 'libera') as posti_liberi,
         array_remove(array_agg(distinct po.ruolo) filter (where po.stato = 'libera'), null) as ruoli_liberi,
         public.distanza_km(p_lat, p_lng, c.lat, c.lng) as distanza_km
  from public.partite p
  join public.campi c on c.id = p.campo_id
  left join public.posizioni po on po.partita_id = p.id
  where p.stato = 'aperta'
    and p.data_ora > now()
    and public.distanza_km(p_lat, p_lng, c.lat, c.lng) <= p_raggio_km
  group by p.id, c.id
  having count(po.id) filter (where po.stato = 'libera') > 0
  order by p.data_ora
  limit p_limite;
$$;

-- campi vicini a un punto
create or replace function public.campi_vicini(
  p_lat double precision,
  p_lng double precision,
  p_raggio_km double precision default 25,
  p_limite int default 50
) returns table (
  id uuid, nome text, indirizzo text, lat double precision, lng double precision,
  sport text[], verificato boolean, distanza_km double precision, partite_aperte bigint
) language sql stable security invoker set search_path = public as $$
  select c.id, c.nome, c.indirizzo, c.lat, c.lng, c.sport, c.verificato,
         public.distanza_km(p_lat, p_lng, c.lat, c.lng),
         (select count(*) from public.partite p
           where p.campo_id = c.id and p.stato = 'aperta' and p.data_ora > now())
  from public.campi c
  where public.distanza_km(p_lat, p_lng, c.lat, c.lng) <= p_raggio_km
  order by 8
  limit p_limite;
$$;

-- ---------------------------------------------------------------------
-- Viste
-- ---------------------------------------------------------------------
-- medie anonime: la vista gira con i privilegi del proprietario, così
-- nessuno legge le singole recensioni ma tutti vedono la media
create or replace view public.profili_voti as
select a_id as profilo_id,
       count(*)::int as n_recensioni,
       round(avg(puntualita)::numeric, 1) as puntualita,
       round(avg(correttezza)::numeric, 1) as correttezza,
       round(avg(livello)::numeric, 1) as livello,
       round(avg(squadra)::numeric, 1) as squadra,
       round(((avg(puntualita) + avg(correttezza) + avg(livello) + avg(squadra)) / 4)::numeric, 1) as complessivo
from public.recensioni
group by a_id;

create or replace view public.storico_partite
with (security_invoker = true) as
select po.giocatore_id,
       p.id as partita_id, p.data_ora, p.formato, p.stato, p.risultato_a, p.risultato_b,
       po.squadra, po.ruolo,
       c.id as campo_id, c.nome as campo_nome,
       case
         when p.stato <> 'giocata' or p.risultato_a is null then null
         when p.risultato_a = p.risultato_b then 'pareggio'
         when (po.squadra = 'A' and p.risultato_a > p.risultato_b)
           or (po.squadra = 'B' and p.risultato_b > p.risultato_a) then 'vinta'
         else 'persa'
       end as esito
from public.posizioni po
join public.partite p on p.id = po.partita_id
join public.campi c on c.id = p.campo_id
where po.giocatore_id is not null;

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.profili enable row level security;
alter table public.campi enable row level security;
alter table public.partite enable row level security;
alter table public.posizioni enable row level security;
alter table public.richieste enable row level security;
alter table public.inviti enable row level security;
alter table public.messaggi enable row level security;
alter table public.recensioni enable row level security;
alter table public.prenotazioni enable row level security;

-- profili: nome/iniziali visibili a chi è loggato; ognuno modifica solo il suo
drop policy if exists "profili leggibili" on public.profili;
create policy "profili leggibili" on public.profili for select to authenticated using (true);
drop policy if exists "profilo proprio insert" on public.profili;
create policy "profilo proprio insert" on public.profili for insert to authenticated with check (id = auth.uid());
drop policy if exists "profilo proprio update" on public.profili;
create policy "profilo proprio update" on public.profili for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- campi: tutti leggono (anche dal QR senza login); chi è loggato li crea
drop policy if exists "campi leggibili" on public.campi;
create policy "campi leggibili" on public.campi for select to anon, authenticated using (true);
drop policy if exists "campi insert" on public.campi;
create policy "campi insert" on public.campi for insert to authenticated with check (creato_da = auth.uid());
drop policy if exists "campi update creatore" on public.campi;
create policy "campi update creatore" on public.campi for update to authenticated using (creato_da = auth.uid());

-- partite: tutti leggono; solo l'organizzatore crea/modifica
drop policy if exists "partite leggibili" on public.partite;
create policy "partite leggibili" on public.partite for select to anon, authenticated using (true);
drop policy if exists "partite insert" on public.partite;
create policy "partite insert" on public.partite for insert to authenticated with check (organizzatore_id = auth.uid());
drop policy if exists "partite update organizzatore" on public.partite;
create policy "partite update organizzatore" on public.partite for update to authenticated
  using (organizzatore_id = auth.uid()) with check (organizzatore_id = auth.uid());

-- posizioni: tutti leggono (posti liberi visibili dal QR)
drop policy if exists "posizioni leggibili" on public.posizioni;
create policy "posizioni leggibili" on public.posizioni for select to anon, authenticated using (true);
drop policy if exists "posizioni organizzatore" on public.posizioni;
create policy "posizioni organizzatore" on public.posizioni for all to authenticated
  using (public.e_organizzatore(partita_id)) with check (public.e_organizzatore(partita_id));
-- un giocatore prende un posto libero
drop policy if exists "posizioni prendi posto" on public.posizioni;
create policy "posizioni prendi posto" on public.posizioni for update to authenticated
  using (stato = 'libera' and giocatore_id is null)
  with check (giocatore_id = auth.uid() and stato = 'occupata');
-- un giocatore lascia il proprio posto (o conferma/rifiuta il cambio ruolo)
drop policy if exists "posizioni posto proprio" on public.posizioni;
create policy "posizioni posto proprio" on public.posizioni for update to authenticated
  using (giocatore_id = auth.uid())
  with check (giocatore_id = auth.uid() or (giocatore_id is null and stato = 'libera'));

-- richieste
drop policy if exists "richieste leggibili" on public.richieste;
create policy "richieste leggibili" on public.richieste for select to authenticated
  using (giocatore_id = auth.uid() or public.e_organizzatore(partita_id));
drop policy if exists "richieste insert" on public.richieste;
create policy "richieste insert" on public.richieste for insert to authenticated with check (giocatore_id = auth.uid());
drop policy if exists "richieste update" on public.richieste;
create policy "richieste update" on public.richieste for update to authenticated
  using (giocatore_id = auth.uid() or public.e_organizzatore(partita_id));

-- inviti
drop policy if exists "inviti leggibili" on public.inviti;
create policy "inviti leggibili" on public.inviti for select to authenticated using (da_id = auth.uid() or a_id = auth.uid());
drop policy if exists "inviti insert" on public.inviti;
create policy "inviti insert" on public.inviti for insert to authenticated with check (da_id = auth.uid() and public.e_organizzatore(partita_id));
drop policy if exists "inviti update destinatario" on public.inviti;
create policy "inviti update destinatario" on public.inviti for update to authenticated using (a_id = auth.uid());

-- messaggi: solo partecipanti
drop policy if exists "messaggi leggibili" on public.messaggi;
create policy "messaggi leggibili" on public.messaggi for select to authenticated using (public.partecipa(partita_id));
drop policy if exists "messaggi insert" on public.messaggi;
create policy "messaggi insert" on public.messaggi for insert to authenticated
  with check (autore_id = auth.uid() and public.partecipa(partita_id));

-- recensioni: scrive chi ha giocato una partita in stato 'giocata'; legge solo le proprie
drop policy if exists "recensioni proprie" on public.recensioni;
create policy "recensioni proprie" on public.recensioni for select to authenticated using (da_id = auth.uid());
drop policy if exists "recensioni insert" on public.recensioni;
create policy "recensioni insert" on public.recensioni for insert to authenticated
  with check (
    da_id = auth.uid()
    and public.partecipa(partita_id)
    and exists (select 1 from public.partite where id = partita_id and stato = 'giocata')
    and exists (select 1 from public.posizioni where partita_id = recensioni.partita_id and giocatore_id = a_id)
  );

-- prenotazioni: per ora sola lettura
drop policy if exists "prenotazioni leggibili" on public.prenotazioni;
create policy "prenotazioni leggibili" on public.prenotazioni for select to anon, authenticated using (true);

-- viste
revoke all on public.profili_voti from anon;
grant select on public.profili_voti to authenticated;
grant select on public.storico_partite to authenticated;

-- ---------------------------------------------------------------------
-- Realtime (tappa 3) – già abilitato per non rifare la migrazione
-- ---------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.messaggi;
  alter publication supabase_realtime add table public.posizioni;
  alter publication supabase_realtime add table public.richieste;
exception when duplicate_object or undefined_object then null;
end $$;
