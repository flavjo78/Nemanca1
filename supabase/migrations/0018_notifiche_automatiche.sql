-- 0018: notifiche push automatiche inviate dal database tramite OneSignal. Rieseguibile.
-- La chiave REST di OneSignal sta nel Vault di Supabase con nome 'onesignal_rest_key'
-- (inserita da Flavio dal pannello, mai nel codice). Senza chiave non parte nulla.
-- Ogni invio è protetto: se OneSignal non risponde, l'azione dell'utente va comunque a buon fine.

-- pg_net esiste su Supabase; su un Postgres di prova si salta senza errori
do $$
begin
  create extension if not exists pg_net with schema extensions;
exception when others then
  raise notice 'pg_net non disponibile: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------
-- invio generico
-- ---------------------------------------------------------------------
create or replace function public.invia_push(
  p_destinatari uuid[], p_titolo text, p_testo text, p_percorso text default '/', p_gruppo text default null
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_chiave text;
  v_dest text[];
  v_corpo jsonb;
begin
  select array_agg(distinct d::text) into v_dest
  from unnest(p_destinatari) d where d is not null;
  if v_dest is null or array_length(v_dest, 1) = 0 then return; end if;

  begin
    select decrypted_secret into v_chiave from vault.decrypted_secrets where name = 'onesignal_rest_key' limit 1;
  exception when others then v_chiave := null;
  end;
  if v_chiave is null or btrim(v_chiave) = '' then return; end if;

  v_corpo := jsonb_build_object(
    'app_id', '27506aa7-d2ae-4a62-8a47-56dad6193dd6',
    'target_channel', 'push',
    'include_aliases', jsonb_build_object('external_id', to_jsonb(v_dest)),
    'headings', jsonb_build_object('en', p_titolo, 'it', p_titolo),
    'contents', jsonb_build_object('en', left(p_testo, 300), 'it', left(p_testo, 300)),
    'url', 'https://www.nemanca1.com' || coalesce(p_percorso, '/')
  );
  if p_gruppo is not null then
    v_corpo := v_corpo || jsonb_build_object('web_push_topic', p_gruppo);
  end if;

  begin
    perform net.http_post(
      url := 'https://api.onesignal.com/notifications?c=push',
      body := v_corpo,
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Key ' || btrim(v_chiave))
    );
  exception when others then
    raise warning 'invia_push: %', sqlerrm;
  end;
end $$;
revoke execute on function public.invia_push(uuid[], text, text, text, text) from public, anon, authenticated;

-- testo breve della partita: "gio 13/11 21:00 · Campo San Rocco"
create or replace function public.descrivi_partita(p_partita uuid)
returns text language sql stable security definer set search_path = public as $$
  select (array['dom','lun','mar','mer','gio','ven','sab'])[extract(dow from p.data_ora at time zone 'Europe/Rome')::int + 1]
         || ' ' || to_char(p.data_ora at time zone 'Europe/Rome', 'DD/MM HH24:MI') || ' · ' || c.nome
  from public.partite p join public.campi c on c.id = p.campo_id where p.id = p_partita;
$$;

-- chi gestisce la partita (organizzatore + vice)
create or replace function public.gestori_partita(p_partita uuid)
returns uuid[] language sql stable security definer set search_path = public as $$
  select array(
    select organizzatore_id from public.partite where id = p_partita
    union select giocatore_id from public.vice where partita_id = p_partita
  );
$$;

-- tutti i partecipanti (organizzatore, vice, giocatori, panchina, tribuna)
create or replace function public.partecipanti_partita(p_partita uuid)
returns uuid[] language sql stable security definer set search_path = public as $$
  select array(
    select organizzatore_id from public.partite where id = p_partita
    union select giocatore_id from public.vice where partita_id = p_partita
    union select giocatore_id from public.posizioni where partita_id = p_partita and giocatore_id is not null
    union select giocatore_id from public.tribuna where partita_id = p_partita
  );
$$;

-- ---------------------------------------------------------------------
-- candidature: nuova → gestori; accettata/rifiutata → giocatore
-- ---------------------------------------------------------------------
create or replace function public.push_richieste()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_nome text; v_desc text;
begin
  begin
    v_desc := public.descrivi_partita(new.partita_id);
    if tg_op = 'INSERT' and new.stato = 'in_attesa' then
      v_nome := public.nome_breve(new.giocatore_id);
      perform public.invia_push(
        array_remove(public.gestori_partita(new.partita_id), new.giocatore_id),
        'Nuova candidatura',
        v_nome || ' vuole giocare' || coalesce(' come ' || public.etichetta_ruolo(new.ruolo_richiesto), '') || ' · ' || v_desc,
        '/chat/' || new.partita_id);
    elsif tg_op = 'UPDATE' and old.stato = 'in_attesa' and new.stato = 'accettata' then
      perform public.invia_push(array[new.giocatore_id], 'Sei dentro!',
        'La tua candidatura è stata accettata · ' || v_desc, '/partita/' || new.partita_id);
    elsif tg_op = 'UPDATE' and old.stato = 'in_attesa' and new.stato = 'rifiutata' then
      perform public.invia_push(array[new.giocatore_id], 'Candidatura non accettata',
        'Per ' || v_desc || ' l''organizzatore ha scelto altri giocatori', '/partita/' || new.partita_id);
    end if;
  exception when others then raise warning 'push_richieste: %', sqlerrm;
  end;
  return new;
end $$;
drop trigger if exists trg_push_richieste on public.richieste;
create trigger trg_push_richieste after insert or update of stato on public.richieste
  for each row execute function public.push_richieste();

-- ---------------------------------------------------------------------
-- inviti ("chiedi di giocare")
-- ---------------------------------------------------------------------
create or replace function public.push_inviti()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.stato = 'in_attesa' and (tg_op = 'INSERT' or old.stato is distinct from 'in_attesa') then
      perform public.invia_push(array[new.a_id], 'Ti invitano a giocare',
        public.nome_breve(new.da_id) || ' ti invita · ' || public.descrivi_partita(new.partita_id), '/');
    end if;
  exception when others then raise warning 'push_inviti: %', sqlerrm;
  end;
  return new;
end $$;
drop trigger if exists trg_push_inviti on public.inviti;
create trigger trg_push_inviti after insert or update of stato on public.inviti
  for each row execute function public.push_inviti();

-- ---------------------------------------------------------------------
-- proposta di cambio ruolo (modalità libera)
-- ---------------------------------------------------------------------
create or replace function public.push_cambio_ruolo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.stato = 'cambio_proposto' and old.stato is distinct from 'cambio_proposto' and new.giocatore_id is not null then
      perform public.invia_push(array[new.giocatore_id], 'Proposta di cambio ruolo',
        'Ti propongono di giocare come ' || public.etichetta_ruolo(new.nuovo_ruolo_proposto) || ' · ' || public.descrivi_partita(new.partita_id),
        '/partita/' || new.partita_id);
    end if;
  exception when others then raise warning 'push_cambio_ruolo: %', sqlerrm;
  end;
  return new;
end $$;
drop trigger if exists trg_push_cambio_ruolo on public.posizioni;
create trigger trg_push_cambio_ruolo after update of stato on public.posizioni
  for each row execute function public.push_cambio_ruolo();

-- ---------------------------------------------------------------------
-- messaggi in chat: al massimo una notifica ogni 3 minuti per persona e partita
-- ---------------------------------------------------------------------
create table if not exists public.push_chat_inviate (
  partita_id uuid not null references public.partite(id) on delete cascade,
  utente_id uuid not null references public.profili(id) on delete cascade,
  inviata_il timestamptz not null default now(),
  primary key (partita_id, utente_id)
);
alter table public.push_chat_inviate enable row level security;

create or replace function public.push_messaggi()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_dest uuid[];
begin
  if new.tipo <> 'testo' then return new; end if;
  begin
    select array_agg(u) into v_dest
    from unnest(public.partecipanti_partita(new.partita_id)) u
    where u <> new.autore_id
      and not exists (select 1 from public.push_chat_inviate x
                      where x.partita_id = new.partita_id and x.utente_id = u
                        and x.inviata_il > now() - interval '3 minutes');
    if v_dest is null then return new; end if;
    insert into public.push_chat_inviate (partita_id, utente_id, inviata_il)
    select new.partita_id, u, now() from unnest(v_dest) u
    on conflict (partita_id, utente_id) do update set inviata_il = excluded.inviata_il;
    perform public.invia_push(v_dest,
      'Chat · ' || public.descrivi_partita(new.partita_id),
      public.nome_breve(new.autore_id) || ': ' || new.testo,
      '/chat/' || new.partita_id, 'chat-' || new.partita_id);
  exception when others then raise warning 'push_messaggi: %', sqlerrm;
  end;
  return new;
end $$;
drop trigger if exists trg_push_messaggi on public.messaggi;
create trigger trg_push_messaggi after insert on public.messaggi
  for each row execute function public.push_messaggi();

-- ---------------------------------------------------------------------
-- nuovo iscritto (quando sceglie il nome) → amministratori
-- ---------------------------------------------------------------------
create or replace function public.push_nuovo_iscritto()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.nome is not null and btrim(new.nome) <> ''
       and (tg_op = 'INSERT' or old.nome is null or btrim(old.nome) = '') then
      perform public.invia_push(
        array(select id from public.profili where admin and id <> new.id),
        'Nuovo iscritto', new.nome || coalesce(' · ' || new.comune, '') || ' si è iscritto a Ne manca 1', '/admin');
    end if;
  exception when others then raise warning 'push_nuovo_iscritto: %', sqlerrm;
  end;
  return new;
end $$;
drop trigger if exists trg_push_nuovo_iscritto on public.profili;
create trigger trg_push_nuovo_iscritto after insert or update of nome on public.profili
  for each row execute function public.push_nuovo_iscritto();
