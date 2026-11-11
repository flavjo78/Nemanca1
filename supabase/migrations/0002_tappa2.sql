-- =====================================================================
-- Tappa 2 – campo disegnato interattivo: posti, candidature, cambio
-- ruolo, schema modificabile, stato partita automatico, amministratore.
-- Eseguire nell'editor SQL di Supabase DOPO 0001_schema.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Amministratore
-- ---------------------------------------------------------------------
alter table public.profili add column if not exists admin boolean not null default false;

create or replace function public.e_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select admin from public.profili where id = auth.uid()), false);
$$;

-- il primo utente registrato (Flavio) diventa amministratore
update public.profili set admin = true
where id = (select id from public.profili order by creato_il limit 1)
  and not exists (select 1 from public.profili where admin);

-- l'amministratore può correggere o cancellare campi e partite
drop policy if exists "campi admin" on public.campi;
create policy "campi admin" on public.campi for all to authenticated
  using (public.e_admin()) with check (public.e_admin());
drop policy if exists "partite admin" on public.partite;
create policy "partite admin" on public.partite for all to authenticated
  using (public.e_admin()) with check (public.e_admin());
drop policy if exists "richieste admin" on public.richieste;
create policy "richieste admin" on public.richieste for select to authenticated
  using (public.e_admin());

-- ---------------------------------------------------------------------
-- Stato partita automatico: completa quando non ci sono posti liberi
-- ---------------------------------------------------------------------
create or replace function public.ricalcola_stato_partita(p_partita uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_liberi int; v_stato text;
begin
  select stato into v_stato from public.partite where id = p_partita;
  if v_stato not in ('aperta', 'completa') then return; end if;
  select count(*) into v_liberi from public.posizioni where partita_id = p_partita and stato = 'libera';
  update public.partite set stato = case when v_liberi = 0 then 'completa' else 'aperta' end
  where id = p_partita and stato <> case when v_liberi = 0 then 'completa' else 'aperta' end;
end $$;

create or replace function public.trg_posizioni_stato()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.ricalcola_stato_partita(coalesce(new.partita_id, old.partita_id));
  return null;
end $$;

drop trigger if exists trg_posizioni_stato on public.posizioni;
create trigger trg_posizioni_stato
after insert or update of stato or delete on public.posizioni
for each row execute function public.trg_posizioni_stato();

-- ---------------------------------------------------------------------
-- Messaggi di sistema (compaiono nella chat della partita, tappa 3)
-- ---------------------------------------------------------------------
create or replace function public.messaggio_sistema(p_partita uuid, p_testo text, p_tipo text default 'sistema', p_rif uuid default null)
returns void language sql security definer set search_path = public as $$
  insert into public.messaggi (partita_id, autore_id, testo, tipo, riferimento_id)
  values (p_partita, null, p_testo, p_tipo, p_rif);
$$;

create or replace function public.nome_breve(p_id uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    nullif(trim(split_part(nome, ' ', 1) || ' ' || left(nullif(split_part(nome, ' ', 2), ''), 1) || case when nullif(split_part(nome, ' ', 2), '') is null then '' else '.' end), ''),
    'Un giocatore')
  from public.profili where id = p_id;
$$;

create or replace function public.etichetta_ruolo(p_ruolo text)
returns text language sql immutable as $$
  select case p_ruolo when 'portiere' then 'portiere' when 'difesa' then 'difensore'
                      when 'centro' then 'centrocampista' when 'attacco' then 'attaccante' else p_ruolo end;
$$;

-- partita in cui si può ancora entrare/uscire
create or replace function public.partita_modificabile(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.partite where id = p_partita
                 and stato in ('aperta', 'completa') and data_ora > now() - interval '2 hours');
$$;

-- ---------------------------------------------------------------------
-- Prendere, cambiare e lasciare un posto
-- ---------------------------------------------------------------------
create or replace function public.prendi_posto(p_posizione uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype; v_mio uuid;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if v_pos.stato <> 'libera' then raise exception 'Questo posto è già occupato'; end if;
  if not public.partita_modificabile(v_pos.partita_id) then raise exception 'La partita non accetta più cambi'; end if;

  -- se ero già seduto in questa partita, mi sposto: libero il vecchio posto
  select id into v_mio from public.posizioni where partita_id = v_pos.partita_id and giocatore_id = auth.uid();
  if v_mio is not null then
    update public.posizioni set stato = 'libera', giocatore_id = null, nuovo_ruolo_proposto = null where id = v_mio;
  end if;

  update public.posizioni set stato = 'occupata', giocatore_id = auth.uid(), nuovo_ruolo_proposto = null where id = p_posizione;
  -- eventuale candidatura pendente non serve più
  update public.richieste set stato = 'accettata' where partita_id = v_pos.partita_id and giocatore_id = auth.uid() and stato = 'in_attesa';

  if v_mio is null then
    perform public.messaggio_sistema(v_pos.partita_id,
      public.nome_breve(auth.uid()) || ' si è unito come ' || public.etichetta_ruolo(v_pos.ruolo) || ' (squadra ' || v_pos.squadra || ')');
  else
    perform public.messaggio_sistema(v_pos.partita_id,
      public.nome_breve(auth.uid()) || ' si è spostato: ' || public.etichetta_ruolo(v_pos.ruolo) || ' (squadra ' || v_pos.squadra || ')');
  end if;
end $$;

create or replace function public.lascia_posto(p_partita uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  select * into v_pos from public.posizioni where partita_id = p_partita and giocatore_id = auth.uid() for update;
  if v_pos.id is null then raise exception 'Non hai un posto in questa partita'; end if;
  if not public.partita_modificabile(p_partita) then raise exception 'La partita non accetta più cambi'; end if;
  update public.posizioni set stato = 'libera', giocatore_id = null, nuovo_ruolo_proposto = null where id = v_pos.id;
  perform public.messaggio_sistema(p_partita, public.nome_breve(auth.uid()) || ' ha lasciato il posto di ' || public.etichetta_ruolo(v_pos.ruolo));
end $$;

-- l'organizzatore libera il posto di un giocatore
create or replace function public.libera_posto(p_posizione uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.e_organizzatore(v_pos.partita_id) and not public.e_admin() then raise exception 'Solo l''organizzatore può farlo'; end if;
  if v_pos.giocatore_id is null then return; end if;
  perform public.messaggio_sistema(v_pos.partita_id, public.nome_breve(v_pos.giocatore_id) || ' è stato tolto dal posto di ' || public.etichetta_ruolo(v_pos.ruolo));
  update public.posizioni set stato = 'libera', giocatore_id = null, nuovo_ruolo_proposto = null where id = p_posizione;
end $$;

-- ---------------------------------------------------------------------
-- Candidature (stile BlaBlaCar)
-- ---------------------------------------------------------------------
create or replace function public.candidati(p_partita uuid, p_ruolo text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  if not public.partita_modificabile(p_partita) then raise exception 'La partita non accetta più candidature'; end if;
  if exists (select 1 from public.posizioni where partita_id = p_partita and giocatore_id = auth.uid()) then
    raise exception 'Sei già in squadra';
  end if;
  if exists (select 1 from public.richieste where partita_id = p_partita and giocatore_id = auth.uid() and stato = 'in_attesa') then
    raise exception 'Hai già una candidatura in attesa';
  end if;
  insert into public.richieste (partita_id, giocatore_id, ruolo_richiesto) values (p_partita, auth.uid(), p_ruolo) returning id into v_id;
  perform public.messaggio_sistema(p_partita,
    public.nome_breve(auth.uid()) || ' si candida' || coalesce(' come ' || public.etichetta_ruolo(p_ruolo), ''), 'richiesta', v_id);
  return v_id;
end $$;

create or replace function public.ritira_candidatura(p_richiesta uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.richieste set stato = 'rifiutata' where id = p_richiesta and giocatore_id = auth.uid() and stato = 'in_attesa';
end $$;

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
    perform public.messaggio_sistema(v_r.partita_id, 'La candidatura di ' || public.nome_breve(v_r.giocatore_id) || ' non è stata accettata');
    return;
  end if;

  -- posto libero con il ruolo richiesto (o qualsiasi), nella squadra con meno giocatori
  select p.id into v_pos from public.posizioni p
  where p.partita_id = v_r.partita_id and p.stato = 'libera'
    and (v_r.ruolo_richiesto is null or p.ruolo = v_r.ruolo_richiesto)
  order by (select count(*) from public.posizioni q where q.partita_id = p.partita_id and q.squadra = p.squadra and q.giocatore_id is not null), p.squadra, p.y
  limit 1;
  if v_pos is null then
    raise exception 'Nessun posto libero% : aggiungi un posto allo schema e riprova',
      coalesce(' come ' || public.etichetta_ruolo(v_r.ruolo_richiesto), '');
  end if;

  update public.posizioni set stato = 'occupata', giocatore_id = v_r.giocatore_id, nuovo_ruolo_proposto = null where id = v_pos;
  update public.richieste set stato = 'accettata' where id = p_richiesta;
  -- eventuali altre candidature dello stesso giocatore per questa partita
  update public.richieste set stato = 'rifiutata' where partita_id = v_r.partita_id and giocatore_id = v_r.giocatore_id and stato = 'in_attesa';
  perform public.messaggio_sistema(v_r.partita_id, public.nome_breve(v_r.giocatore_id) || ' è stato accettato in squadra');
end $$;

-- ---------------------------------------------------------------------
-- Cambio ruolo proposto dall'organizzatore, da confermare dal giocatore
-- ---------------------------------------------------------------------
create or replace function public.proponi_cambio(p_posizione uuid, p_nuovo_ruolo text)
returns void language plpgsql security definer set search_path = public as $$
declare v_pos public.posizioni%rowtype;
begin
  select * into v_pos from public.posizioni where id = p_posizione for update;
  if v_pos.id is null then raise exception 'Posto non trovato'; end if;
  if not public.e_organizzatore(v_pos.partita_id) then raise exception 'Solo l''organizzatore può proporre un cambio'; end if;
  if v_pos.giocatore_id is null then
    -- posto libero: il ruolo si cambia direttamente
    update public.posizioni set ruolo = p_nuovo_ruolo where id = p_posizione;
    return;
  end if;
  if v_pos.giocatore_id = auth.uid() then
    update public.posizioni set ruolo = p_nuovo_ruolo, stato = 'occupata', nuovo_ruolo_proposto = null where id = p_posizione;
    return;
  end if;
  if v_pos.ruolo = p_nuovo_ruolo then raise exception 'È già il suo ruolo'; end if;
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
    update public.posizioni set ruolo = v_pos.nuovo_ruolo_proposto, stato = 'occupata', nuovo_ruolo_proposto = null where id = p_posizione;
    perform public.messaggio_sistema(v_pos.partita_id, public.nome_breve(auth.uid()) || ' ha accettato: ora gioca ' || public.etichetta_ruolo(v_pos.nuovo_ruolo_proposto));
  else
    update public.posizioni set stato = 'occupata', nuovo_ruolo_proposto = null where id = p_posizione;
    perform public.messaggio_sistema(v_pos.partita_id, public.nome_breve(auth.uid()) || ' preferisce restare ' || public.etichetta_ruolo(v_pos.ruolo));
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Schema: l'organizzatore aggiunge o toglie posti
-- ---------------------------------------------------------------------
create or replace function public.aggiungi_posto(p_partita uuid, p_squadra char, p_ruolo text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.e_organizzatore(p_partita) then raise exception 'Solo l''organizzatore può modificare lo schema'; end if;
  if not public.partita_modificabile(p_partita) then raise exception 'La partita non si può più modificare'; end if;
  if (select count(*) from public.posizioni where partita_id = p_partita and squadra = p_squadra) >= 11 then
    raise exception 'Una squadra può avere al massimo 11 posti';
  end if;
  insert into public.posizioni (partita_id, squadra, ruolo, x, y)
  values (p_partita, p_squadra, p_ruolo, 50, case p_ruolo when 'portiere' then 10 when 'difesa' then 36 when 'centro' then 58 else 80 end)
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
  if (select count(*) from public.posizioni where partita_id = v_pos.partita_id and squadra = v_pos.squadra) <= 1 then
    raise exception 'Ogni squadra deve avere almeno un posto';
  end if;
  delete from public.posizioni where id = p_posizione;
end $$;

-- ---------------------------------------------------------------------
-- Vista per l'amministratore: ultimi iscritti con email
-- (gira con i privilegi del proprietario; l'accesso è filtrato da e_admin)
-- ---------------------------------------------------------------------
create or replace function public.admin_utenti(p_limite int default 50)
returns table (id uuid, nome text, comune text, email text, creato_il timestamptz, ultimo_accesso timestamptz, admin boolean)
language sql stable security definer set search_path = public as $$
  select p.id, p.nome, p.comune, u.email::text, p.creato_il, u.last_sign_in_at, p.admin
  from public.profili p join auth.users u on u.id = p.id
  where public.e_admin()
  order by p.creato_il desc
  limit p_limite;
$$;

create or replace function public.admin_numeri()
returns table (utenti bigint, campi bigint, partite_aperte bigint, partite_settimana bigint, partite_totali bigint)
language sql stable security definer set search_path = public as $$
  select (select count(*) from public.profili),
         (select count(*) from public.campi),
         (select count(*) from public.partite where stato = 'aperta' and data_ora > now()),
         (select count(*) from public.partite where data_ora between now() and now() + interval '7 days' and stato <> 'annullata'),
         (select count(*) from public.partite)
  where public.e_admin();
$$;

-- realtime anche sulle partite (cambio stato)
do $$
begin
  alter publication supabase_realtime add table public.partite;
exception when duplicate_object or undefined_object then null;
end $$;
