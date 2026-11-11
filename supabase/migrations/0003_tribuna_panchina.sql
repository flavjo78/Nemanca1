-- =====================================================================
-- Tribuna (spettatori), modalità "decido io chi gioca", panchine.
-- Eseguire nell'editor SQL di Supabase DOPO 0002_tappa2.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Ruolo "panchina" ammesso ovunque
-- ---------------------------------------------------------------------
alter table public.posizioni drop constraint if exists posizioni_ruolo_check;
alter table public.posizioni add constraint posizioni_ruolo_check
  check (ruolo in ('portiere','difesa','centro','attacco','panchina'));
alter table public.posizioni drop constraint if exists posizioni_nuovo_ruolo_proposto_check;
alter table public.posizioni add constraint posizioni_nuovo_ruolo_proposto_check
  check (nuovo_ruolo_proposto in ('portiere','difesa','centro','attacco','panchina'));
alter table public.richieste drop constraint if exists richieste_ruolo_richiesto_check;
alter table public.richieste add constraint richieste_ruolo_richiesto_check
  check (ruolo_richiesto in ('portiere','difesa','centro','attacco','panchina'));

-- ---------------------------------------------------------------------
-- Impostazioni della partita
-- ---------------------------------------------------------------------
alter table public.partite add column if not exists modalita text not null default 'libera';
alter table public.partite drop constraint if exists partite_modalita_check;
alter table public.partite add constraint partite_modalita_check check (modalita in ('libera','approvazione'));
alter table public.partite add column if not exists panchina smallint not null default 0;
alter table public.partite drop constraint if exists partite_panchina_check;
alter table public.partite add constraint partite_panchina_check check (panchina between 0 and 7);

-- ---------------------------------------------------------------------
-- Tribuna: chi segue la partita senza giocare (può stare in chat)
-- ---------------------------------------------------------------------
create table if not exists public.tribuna (
  partita_id uuid not null references public.partite(id) on delete cascade,
  giocatore_id uuid not null references public.profili(id) on delete cascade,
  creato_il timestamptz not null default now(),
  primary key (partita_id, giocatore_id)
);
alter table public.tribuna enable row level security;
drop policy if exists "tribuna leggibile" on public.tribuna;
create policy "tribuna leggibile" on public.tribuna for select to authenticated using (true);

-- invito a giocare su un posto preciso
alter table public.inviti add column if not exists posizione_id uuid references public.posizioni(id) on delete set null;
alter table public.inviti add column if not exists aggiornato_il timestamptz not null default now();

-- in tribuna si partecipa alla chat
create or replace function public.partecipa(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.e_organizzatore(p_partita)
      or exists (select 1 from public.posizioni where partita_id = p_partita and giocatore_id = auth.uid())
      or exists (select 1 from public.tribuna where partita_id = p_partita and giocatore_id = auth.uid());
$$;

-- ---------------------------------------------------------------------
-- Stato "completa": conta solo i posti in campo, non la panchina
-- ---------------------------------------------------------------------
create or replace function public.ricalcola_stato_partita(p_partita uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_liberi int; v_stato text;
begin
  select stato into v_stato from public.partite where id = p_partita;
  if v_stato not in ('aperta', 'completa') then return; end if;
  select count(*) into v_liberi from public.posizioni
  where partita_id = p_partita and stato = 'libera' and ruolo <> 'panchina';
  update public.partite set stato = case when v_liberi = 0 then 'completa' else 'aperta' end
  where id = p_partita and stato <> case when v_liberi = 0 then 'completa' else 'aperta' end;
end $$;

create or replace function public.etichetta_ruolo(p_ruolo text)
returns text language sql immutable as $$
  select case p_ruolo when 'portiere' then 'portiere' when 'difesa' then 'difensore'
                      when 'centro' then 'centrocampista' when 'attacco' then 'attaccante'
                      when 'panchina' then 'riserva in panchina' else p_ruolo end;
$$;

-- ---------------------------------------------------------------------
-- Creazione partita con modalità e panchine
-- ---------------------------------------------------------------------
drop function if exists public.crea_partita(uuid, smallint, timestamptz, text, numeric, text, char, text);
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
  p_panchina smallint default 0
) returns uuid language plpgsql security invoker set search_path = public as $$
declare
  v_id uuid;
  v_posto uuid;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;

  insert into public.partite (campo_id, organizzatore_id, sport, formato, data_ora, descrizione, quota, modalita, panchina)
  values (p_campo_id, auth.uid(), p_sport, p_formato, p_data_ora, p_descrizione, coalesce(p_quota, 0),
          coalesce(p_modalita, 'libera'), coalesce(p_panchina, 0))
  returning id into v_id;

  insert into public.posizioni (partita_id, squadra, ruolo, x, y)
  select v_id, s.squadra, sp.ruolo, sp.x, sp.y
  from public.schema_predefinito(p_formato) sp
  cross join (values ('A'), ('B')) as s(squadra);

  insert into public.posizioni (partita_id, squadra, ruolo, x, y)
  select v_id, s.squadra, 'panchina', 0, g
  from generate_series(1, coalesce(p_panchina, 0)) g
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
grant execute on function public.crea_partita(uuid, smallint, timestamptz, text, numeric, text, char, text, text, smallint) to authenticated;

-- ---------------------------------------------------------------------
-- Prendere posto: in modalità "approvazione" solo l'organizzatore assegna
-- ---------------------------------------------------------------------
create or replace function public.prendi_posto(p_posizione uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype; v_mio uuid; v_modalita text;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if v_pos.stato <> 'libera' then raise exception 'Questo posto è già occupato'; end if;
  if not public.partita_modificabile(v_pos.partita_id) then raise exception 'La partita non accetta più cambi'; end if;
  select modalita into v_modalita from public.partite where id = v_pos.partita_id;
  if v_modalita = 'approvazione' and not public.e_organizzatore(v_pos.partita_id) then
    raise exception 'In questa partita i posti li assegna l''organizzatore: candidati o entra in tribuna';
  end if;

  select id into v_mio from public.posizioni where partita_id = v_pos.partita_id and giocatore_id = auth.uid();
  if v_mio is not null then
    update public.posizioni set stato = 'libera', giocatore_id = null, nuovo_ruolo_proposto = null where id = v_mio;
  end if;

  update public.posizioni set stato = 'occupata', giocatore_id = auth.uid(), nuovo_ruolo_proposto = null where id = p_posizione;
  update public.richieste set stato = 'accettata' where partita_id = v_pos.partita_id and giocatore_id = auth.uid() and stato = 'in_attesa';
  update public.inviti set stato = 'accettato', aggiornato_il = now() where partita_id = v_pos.partita_id and a_id = auth.uid() and stato = 'in_attesa';
  delete from public.tribuna where partita_id = v_pos.partita_id and giocatore_id = auth.uid();

  if v_mio is null then
    perform public.messaggio_sistema(v_pos.partita_id,
      public.nome_breve(auth.uid()) || ' si è unito come ' || public.etichetta_ruolo(v_pos.ruolo) || ' (squadra ' || v_pos.squadra || ')');
  else
    perform public.messaggio_sistema(v_pos.partita_id,
      public.nome_breve(auth.uid()) || ' si è spostato: ' || public.etichetta_ruolo(v_pos.ruolo) || ' (squadra ' || v_pos.squadra || ')');
  end if;
end $$;

-- chi lascia il posto resta in tribuna, così vede ancora la chat
create or replace function public.lascia_posto(p_partita uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  select * into v_pos from public.posizioni where partita_id = p_partita and giocatore_id = auth.uid() for update;
  if v_pos.id is null then raise exception 'Non hai un posto in questa partita'; end if;
  if not public.partita_modificabile(p_partita) then raise exception 'La partita non accetta più cambi'; end if;
  update public.posizioni set stato = 'libera', giocatore_id = null, nuovo_ruolo_proposto = null where id = v_pos.id;
  insert into public.tribuna (partita_id, giocatore_id) values (p_partita, auth.uid()) on conflict do nothing;
  perform public.messaggio_sistema(p_partita, public.nome_breve(auth.uid()) || ' ha lasciato il posto di ' || public.etichetta_ruolo(v_pos.ruolo) || ' ed è in tribuna');
end $$;

create or replace function public.libera_posto(p_posizione uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.e_organizzatore(v_pos.partita_id) and not public.e_admin() then raise exception 'Solo l''organizzatore può farlo'; end if;
  if v_pos.giocatore_id is null then return; end if;
  perform public.messaggio_sistema(v_pos.partita_id, public.nome_breve(v_pos.giocatore_id) || ' è stato spostato in tribuna');
  insert into public.tribuna (partita_id, giocatore_id) values (v_pos.partita_id, v_pos.giocatore_id) on conflict do nothing;
  update public.posizioni set stato = 'libera', giocatore_id = null, nuovo_ruolo_proposto = null where id = p_posizione;
end $$;

-- ---------------------------------------------------------------------
-- Tribuna: entrare e uscire
-- ---------------------------------------------------------------------
create or replace function public.entra_tribuna(p_partita uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  if not exists (select 1 from public.partite where id = p_partita and stato <> 'annullata') then raise exception 'Partita non disponibile'; end if;
  if exists (select 1 from public.posizioni where partita_id = p_partita and giocatore_id = auth.uid()) then raise exception 'Sei già in campo'; end if;
  if public.e_organizzatore(p_partita) then raise exception 'Sei l''organizzatore'; end if;
  insert into public.tribuna (partita_id, giocatore_id) values (p_partita, auth.uid()) on conflict do nothing;
  if found then
    perform public.messaggio_sistema(p_partita, public.nome_breve(auth.uid()) || ' è in tribuna');
  end if;
end $$;

create or replace function public.esci_tribuna(p_partita uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.tribuna where partita_id = p_partita and giocatore_id = auth.uid();
  update public.inviti set stato = 'rifiutato', aggiornato_il = now() where partita_id = p_partita and a_id = auth.uid() and stato = 'in_attesa';
end $$;

-- ---------------------------------------------------------------------
-- L'organizzatore chiede a qualcuno di giocare in un posto libero
-- ---------------------------------------------------------------------
create or replace function public.chiedi_di_giocare(p_posizione uuid, p_giocatore uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype;
begin
  select * into v_pos from public.posizioni where id = p_posizione;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.e_organizzatore(v_pos.partita_id) then raise exception 'Solo l''organizzatore può chiedere'; end if;
  if v_pos.stato <> 'libera' then raise exception 'Il posto non è più libero'; end if;
  if exists (select 1 from public.posizioni where partita_id = v_pos.partita_id and giocatore_id = p_giocatore) then raise exception 'È già in campo'; end if;
  insert into public.inviti (partita_id, da_id, a_id, posizione_id, stato, aggiornato_il)
  values (v_pos.partita_id, auth.uid(), p_giocatore, p_posizione, 'in_attesa', now())
  on conflict (partita_id, a_id) do update set posizione_id = excluded.posizione_id, stato = 'in_attesa', da_id = excluded.da_id, aggiornato_il = now();
  insert into public.tribuna (partita_id, giocatore_id) values (v_pos.partita_id, p_giocatore) on conflict do nothing;
  perform public.messaggio_sistema(v_pos.partita_id,
    'L''organizzatore chiede a ' || public.nome_breve(p_giocatore) || ' di giocare come ' || public.etichetta_ruolo(v_pos.ruolo) || ' (squadra ' || v_pos.squadra || ')');
end $$;

create or replace function public.rispondi_invito(p_partita uuid, p_accetta boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_inv public.inviti%rowtype; v_pos public.posizioni%rowtype; v_mio uuid;
begin
  select * into v_inv from public.inviti where partita_id = p_partita and a_id = auth.uid() and stato = 'in_attesa' for update;
  if v_inv.id is null then raise exception 'Nessuna richiesta in sospeso'; end if;
  if not p_accetta then
    update public.inviti set stato = 'rifiutato', aggiornato_il = now() where id = v_inv.id;
    perform public.messaggio_sistema(p_partita, public.nome_breve(auth.uid()) || ' per ora resta in tribuna');
    return;
  end if;
  select * into v_pos from public.posizioni where id = v_inv.posizione_id for update;
  if v_pos.id is null or v_pos.stato <> 'libera' then
    update public.inviti set stato = 'rifiutato', aggiornato_il = now() where id = v_inv.id;
    raise exception 'Nel frattempo il posto è stato preso: chiedi all''organizzatore';
  end if;
  select id into v_mio from public.posizioni where partita_id = p_partita and giocatore_id = auth.uid();
  if v_mio is not null then
    update public.posizioni set stato = 'libera', giocatore_id = null, nuovo_ruolo_proposto = null where id = v_mio;
  end if;
  update public.posizioni set stato = 'occupata', giocatore_id = auth.uid(), nuovo_ruolo_proposto = null where id = v_pos.id;
  update public.inviti set stato = 'accettato', aggiornato_il = now() where id = v_inv.id;
  update public.richieste set stato = 'accettata' where partita_id = p_partita and giocatore_id = auth.uid() and stato = 'in_attesa';
  delete from public.tribuna where partita_id = p_partita and giocatore_id = auth.uid();
  perform public.messaggio_sistema(p_partita,
    public.nome_breve(auth.uid()) || ' scende in campo come ' || public.etichetta_ruolo(v_pos.ruolo) || ' (squadra ' || v_pos.squadra || ')');
end $$;

-- ---------------------------------------------------------------------
-- Candidature: accettando, prima i posti in campo, poi la panchina
-- ---------------------------------------------------------------------
create or replace function public.rispondi_richiesta(p_richiesta uuid, p_accetta boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_r public.richieste%rowtype; v_pos uuid;
begin
  select * into v_r from public.richieste where id = p_richiesta for update;
  if v_r.id is null then raise exception 'Richiesta non trovata'; end if;
  if not public.e_organizzatore(v_r.partita_id) and not public.e_admin() then raise exception 'Solo l''organizzatore può rispondere'; end if;
  if v_r.stato <> 'in_attesa' then raise exception 'Richiesta già gestita'; end if;

  if not p_accetta then
    update public.richieste set stato = 'rifiutata' where id = p_richiesta;
    insert into public.tribuna (partita_id, giocatore_id) values (v_r.partita_id, v_r.giocatore_id) on conflict do nothing;
    perform public.messaggio_sistema(v_r.partita_id, 'La candidatura di ' || public.nome_breve(v_r.giocatore_id) || ' non è stata accettata: resta in tribuna');
    return;
  end if;

  select p.id into v_pos from public.posizioni p
  where p.partita_id = v_r.partita_id and p.stato = 'libera'
    and (v_r.ruolo_richiesto is null or p.ruolo = v_r.ruolo_richiesto)
  order by (p.ruolo = 'panchina'),
           (select count(*) from public.posizioni q where q.partita_id = p.partita_id and q.squadra = p.squadra and q.giocatore_id is not null),
           p.squadra, p.y
  limit 1;
  if v_pos is null then
    raise exception 'Nessun posto libero% : aggiungi un posto allo schema e riprova',
      coalesce(' come ' || public.etichetta_ruolo(v_r.ruolo_richiesto), '');
  end if;

  update public.posizioni set stato = 'occupata', giocatore_id = v_r.giocatore_id, nuovo_ruolo_proposto = null where id = v_pos;
  update public.richieste set stato = 'accettata' where id = p_richiesta;
  update public.richieste set stato = 'rifiutata' where partita_id = v_r.partita_id and giocatore_id = v_r.giocatore_id and stato = 'in_attesa';
  delete from public.tribuna where partita_id = v_r.partita_id and giocatore_id = v_r.giocatore_id;
  perform public.messaggio_sistema(v_r.partita_id, public.nome_breve(v_r.giocatore_id) || ' è stato accettato in squadra');
end $$;

-- ---------------------------------------------------------------------
-- Schema: limiti separati per campo (11) e panchina (7)
-- ---------------------------------------------------------------------
create or replace function public.aggiungi_posto(p_partita uuid, p_squadra char, p_ruolo text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.e_organizzatore(p_partita) then raise exception 'Solo l''organizzatore può modificare lo schema'; end if;
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
end $$;

create or replace function public.rimuovi_posto(p_posizione uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.e_organizzatore(v_pos.partita_id) then raise exception 'Solo l''organizzatore può modificare lo schema'; end if;
  if v_pos.giocatore_id is not null then raise exception 'Il posto è occupato: prima liberalo'; end if;
  if v_pos.ruolo <> 'panchina' and (select count(*) from public.posizioni where partita_id = v_pos.partita_id and squadra = v_pos.squadra and ruolo <> 'panchina') <= 1 then
    raise exception 'Ogni squadra deve avere almeno un posto in campo';
  end if;
  delete from public.posizioni where id = p_posizione;
end $$;

-- partite vicine: i posti liberi contano solo quelli in campo
create or replace function public.partite_vicine(
  p_lat double precision, p_lng double precision,
  p_raggio_km double precision default 25, p_limite int default 20
) returns table (
  id uuid, campo_id uuid, campo_nome text, campo_indirizzo text,
  organizzatore_id uuid, formato smallint, data_ora timestamptz, quota numeric,
  descrizione text, posti_liberi bigint, ruoli_liberi text[], distanza_km double precision
) language sql stable security invoker set search_path = public as $$
  select p.id, c.id, c.nome, c.indirizzo,
         p.organizzatore_id, p.formato, p.data_ora, p.quota, p.descrizione,
         count(po.id) filter (where po.stato = 'libera' and po.ruolo <> 'panchina') as posti_liberi,
         array_remove(array_agg(distinct po.ruolo) filter (where po.stato = 'libera' and po.ruolo <> 'panchina'), null) as ruoli_liberi,
         public.distanza_km(p_lat, p_lng, c.lat, c.lng) as distanza_km
  from public.partite p
  join public.campi c on c.id = p.campo_id
  left join public.posizioni po on po.partita_id = p.id
  where p.stato = 'aperta' and p.data_ora > now()
    and public.distanza_km(p_lat, p_lng, c.lat, c.lng) <= p_raggio_km
  group by p.id, c.id
  having count(po.id) filter (where po.stato = 'libera' and po.ruolo <> 'panchina') > 0
  order by p.data_ora
  limit p_limite;
$$;

-- realtime su tribuna e inviti
do $$
begin
  alter publication supabase_realtime add table public.tribuna;
exception when duplicate_object or undefined_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.inviti;
exception when duplicate_object or undefined_object then null;
end $$;

grant select on public.tribuna to authenticated;
grant select on public.tribuna to anon;
