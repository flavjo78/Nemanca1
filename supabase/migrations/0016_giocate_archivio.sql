-- 0016: partite giocate e archivio. Rieseguibile.
-- * un'ora dopo l'inizio la partita diventa "giocata": esce dagli elenchi delle
--   partite aperte e la chat diventa di sola lettura;
-- * dal giorno dopo (ora italiana) va in archivio.
-- Nulla viene cancellato: formazione, modulo, partecipanti, panchina, tribuna,
-- chat e (in futuro) risultato restano conservati.

alter table public.partite add column if not exists archiviata boolean not null default false;
alter table public.partite add column if not exists archiviata_il timestamptz;
create index if not exists partite_archiviata_idx on public.partite (archiviata, data_ora);

-- la partita si può ancora modificare? (fino a un'ora dopo l'inizio)
create or replace function public.partita_modificabile(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.partite where id = p_partita
                 and stato in ('aperta', 'completa') and data_ora > now() - interval '1 hour');
$$;

-- la chat accetta nuovi messaggi? stessa regola: dopo un'ora dall'inizio è chiusa
create or replace function public.chat_attiva(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.partita_modificabile(p_partita);
$$;
grant execute on function public.chat_attiva(uuid) to anon, authenticated;

drop policy if exists "messaggi insert" on public.messaggi;
create policy "messaggi insert" on public.messaggi for insert to authenticated
  with check (autore_id = auth.uid() and tipo = 'testo'
              and public.partecipa(partita_id) and public.chat_attiva(partita_id));

-- aggiorna gli stati in base all'orario (lanciata ogni 5 minuti da pg_cron)
create or replace function public.aggiorna_stati_partite()
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.partite set stato = 'giocata'
  where stato in ('aperta', 'completa') and data_ora <= now() - interval '1 hour';


  update public.partite set archiviata = true, archiviata_il = now()
  where not archiviata and stato in ('giocata', 'annullata')
    and (data_ora at time zone 'Europe/Rome')::date < (now() at time zone 'Europe/Rome')::date;
end $$;
revoke execute on function public.aggiorna_stati_partite() from public, anon, authenticated;

-- pg_cron esiste su Supabase; su un Postgres di prova senza pg_cron si salta senza errori
do $$
begin
  create extension if not exists pg_cron;
  begin
    perform cron.unschedule('aggiorna-stati-partite');
  exception when others then null;
  end;
  perform cron.schedule('aggiorna-stati-partite', '*/5 * * * *', 'select public.aggiorna_stati_partite()');
exception when others then
  raise notice 'pg_cron non disponibile: %', sqlerrm;
end $$;

-- elenco chat: tutte (anche archiviate, in sola lettura), prima quelle ancora attive
drop function if exists public.mie_chat();
create or replace function public.mie_chat()
returns table (
  partita_id uuid, data_ora timestamptz, formato smallint, stato text, campo_nome text,
  ultimo_testo text, ultimo_tipo text, ultimo_autore text, ultimo_il timestamptz, messaggi bigint,
  archiviata boolean, attiva boolean
) language sql stable security definer set search_path = public as $$
  select p.id, p.data_ora, p.formato, p.stato, c.nome,
         m.testo, m.tipo, pr.nome, m.creato_il,
         (select count(*) from public.messaggi x where x.partita_id = p.id),
         p.archiviata,
         (p.stato in ('aperta', 'completa') and p.data_ora > now() - interval '1 hour')
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
  order by (p.stato in ('aperta', 'completa') and p.data_ora > now() - interval '1 hour') desc,
           coalesce(m.creato_il, p.creato_il) desc;
$$;
grant execute on function public.mie_chat() to authenticated;

-- le mie partite giocate o archiviate (organizzatore, giocatore, panchina, vice o tribuna)
create or replace function public.mie_partite_passate(p_archiviate boolean)
returns table (
  partita_id uuid, data_ora timestamptz, formato smallint, stato text, campo_id uuid, campo_nome text,
  risultato_a smallint, risultato_b smallint, mio_ruolo text, mia_squadra char(1),
  giocatori bigint, in_tribuna bigint, organizzatore boolean
) language sql stable security definer set search_path = public as $$
  select p.id, p.data_ora, p.formato, p.stato, c.id, c.nome,
         p.risultato_a::smallint, p.risultato_b::smallint,
         coalesce(mia.ruolo, case when exists (select 1 from public.tribuna t where t.partita_id = p.id and t.giocatore_id = auth.uid()) then 'tribuna' end),
         mia.squadra,
         (select count(*) from public.posizioni x where x.partita_id = p.id and x.giocatore_id is not null),
         (select count(*) from public.tribuna t where t.partita_id = p.id),
         p.organizzatore_id = auth.uid()
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

-- primo giro subito
select public.aggiorna_stati_partite();
