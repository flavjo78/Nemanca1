-- 0031: durata della partita, ospiti senza app, voto del migliore in campo (con coppa),
-- voti facoltativi ai compagni, azioni dell'amministratore. Rieseguibile.

-- ---------------------------------------------------------------------
-- Durata (minuti). La partita finisce a data_ora + durata.
-- ---------------------------------------------------------------------
alter table public.partite add column if not exists durata_min smallint not null default 60;
alter table public.partite drop constraint if exists partite_durata_valida;
alter table public.partite add constraint partite_durata_valida check (durata_min between 15 and 300);

create or replace function public.fine_partita(p public.partite)
returns timestamptz language sql immutable as $$
  select p.data_ora + make_interval(mins => p.durata_min);
$$;

create or replace function public.imposta_durata(p_partita uuid, p_minuti int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.e_organizzatore(p_partita) then raise exception 'Solo l''organizzatore può cambiare la durata'; end if;
  if p_minuti is null or p_minuti < 15 or p_minuti > 300 then raise exception 'La durata va da 15 a 300 minuti'; end if;
  update public.partite set durata_min = p_minuti where id = p_partita;
end $$;
grant execute on function public.imposta_durata(uuid, int) to authenticated;

-- si può modificare fino alla fine della partita
create or replace function public.partita_modificabile(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.partite p where p.id = p_partita
                 and p.stato in ('aperta', 'completa') and now() < public.fine_partita(p));
$$;

-- ---------------------------------------------------------------------
-- Ospiti: posti occupati da chi non ha l'app (solo il nome)
-- ---------------------------------------------------------------------
alter table public.posizioni add column if not exists ospite_nome text;
alter table public.posizioni drop constraint if exists posizioni_ospite_valido;
alter table public.posizioni add constraint posizioni_ospite_valido
  check (ospite_nome is null or (giocatore_id is null and char_length(btrim(ospite_nome)) between 1 and 40));

create or replace function public.metti_ospite(p_posizione uuid, p_nome text)
returns void language plpgsql security definer set search_path = public as $$
declare v public.posizioni%rowtype;
begin
  select * into v from public.posizioni where id = p_posizione for update;
  if v.id is null then raise exception 'Posto non trovato'; end if;
  if not public.puo_gestire_squadra(v.partita_id, v.squadra) then raise exception 'Solo chi gestisce la squadra può aggiungere un ospite'; end if;
  if not public.partita_modificabile(v.partita_id) then raise exception 'La partita non si può più modificare'; end if;
  if v.stato <> 'libera' then raise exception 'Il posto non è libero'; end if;
  if char_length(btrim(coalesce(p_nome, ''))) = 0 then raise exception 'Scrivi il nome dell''ospite'; end if;
  update public.posizioni set stato = 'occupata', ospite_nome = left(btrim(p_nome), 40), giocatore_id = null where id = v.id;
  perform public.messaggio_sistema(v.partita_id,
    left(btrim(p_nome), 40) || ' (ospite senza app) gioca come ' || public.etichetta_ruolo(v.ruolo) || ' (squadra ' || v.squadra || ')');
end $$;

create or replace function public.togli_ospite(p_posizione uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v public.posizioni%rowtype;
begin
  select * into v from public.posizioni where id = p_posizione for update;
  if v.id is null or v.ospite_nome is null then raise exception 'Qui non c''è un ospite'; end if;
  if not public.puo_gestire_squadra(v.partita_id, v.squadra) then raise exception 'Solo chi gestisce la squadra può togliere un ospite'; end if;
  update public.posizioni set stato = 'libera', ospite_nome = null where id = v.id;
end $$;
grant execute on function public.metti_ospite(uuid, text), public.togli_ospite(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Migliore in campo
-- ---------------------------------------------------------------------
alter table public.partite add column if not exists mvp_stato text;   -- null = votazione aperta/non iniziata, 'valida', 'non_valida', 'nessun_voto'
alter table public.partite drop constraint if exists partite_mvp_stato_valido;
alter table public.partite add constraint partite_mvp_stato_valido check (mvp_stato is null or mvp_stato in ('valida', 'non_valida', 'nessun_voto'));
alter table public.partite add column if not exists mvp_ids uuid[];
alter table public.profili add column if not exists coppe int not null default 0;

create table if not exists public.voti_mvp (
  partita_id uuid not null references public.partite(id) on delete cascade,
  votante_id uuid not null references public.profili(id) on delete cascade,
  votato_id uuid references public.profili(id) on delete cascade,  -- null = "non c'ero"
  creato_il timestamptz not null default now(),
  primary key (partita_id, votante_id)
);
alter table public.voti_mvp enable row level security;
drop policy if exists "voti mvp miei" on public.voti_mvp;
create policy "voti mvp miei" on public.voti_mvp for select to authenticated using (votante_id = auth.uid());

-- chi partecipa alla votazione: giocatori (campo e panchina), tribuna, organizzatore e vice
create or replace function public.votanti_partita(p_partita uuid)
returns uuid[] language sql stable security definer set search_path = public as $$
  select public.partecipanti_partita(p_partita);
$$;

-- le votazioni che mi aspettano: partite finite da meno di 24 ore, dove partecipo e non ho ancora votato
create or replace function public.voti_da_dare()
returns table (partita_id uuid, data_ora timestamptz, campo_nome text, formato smallint, candidati jsonb)
language sql stable security definer set search_path = public as $$
  select p.id, p.data_ora, c.nome, p.formato,
         coalesce((select jsonb_agg(jsonb_build_object('id', pr.id, 'nome', pr.nome, 'iniziali', pr.iniziali, 'foto_url', pr.foto_url,
                                                       'squadra', po.squadra, 'ruolo', po.ruolo) order by po.squadra, pr.nome)
                   from public.posizioni po join public.profili pr on pr.id = po.giocatore_id
                   where po.partita_id = p.id), '[]'::jsonb)
  from public.partite p join public.campi c on c.id = p.campo_id
  where auth.uid() is not null
    and p.stato <> 'annullata'
    and now() >= public.fine_partita(p)
    and now() < public.fine_partita(p) + interval '24 hours'
    and p.mvp_stato is null
    and auth.uid() = any(public.votanti_partita(p.id))
    and exists (select 1 from public.posizioni po where po.partita_id = p.id and po.giocatore_id is not null)
    and not exists (select 1 from public.voti_mvp v where v.partita_id = p.id and v.votante_id = auth.uid())
  order by p.data_ora;
$$;

create or replace function public.vota_mvp(p_partita uuid, p_votato uuid)
returns void language plpgsql security definer set search_path = public as $$
declare p public.partite%rowtype;
begin
  select * into p from public.partite where id = p_partita;
  if p.id is null then raise exception 'Partita non trovata'; end if;
  if not (auth.uid() = any(public.votanti_partita(p_partita))) then raise exception 'Non hai partecipato a questa partita'; end if;
  if now() < public.fine_partita(p) then raise exception 'La partita non è ancora finita'; end if;
  if p.mvp_stato is not null then raise exception 'La votazione è già chiusa'; end if;
  if p_votato is not null and not exists (select 1 from public.posizioni where partita_id = p_partita and giocatore_id = p_votato) then
    raise exception 'Puoi votare solo chi ha giocato';
  end if;
  if p_votato = auth.uid() then raise exception 'Non puoi votare te stesso'; end if;
  insert into public.voti_mvp (partita_id, votante_id, votato_id) values (p_partita, auth.uid(), p_votato)
  on conflict (partita_id, votante_id) do nothing;
  -- se hanno risposto tutti, si chiude subito
  if (select count(*) from public.voti_mvp where partita_id = p_partita) >= coalesce(array_length(public.votanti_partita(p_partita), 1), 0) then
    perform public.chiudi_votazione(p_partita);
  end if;
end $$;

-- chiude la votazione: valida se ha votato (non "non c'ero") almeno la metà dei partecipanti
create or replace function public.chiudi_votazione(p_partita uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_part int; v_voti int; v_max int; v_vincitori uuid[]; v_nomi text;
begin
  if (select mvp_stato from public.partite where id = p_partita) is not null then return; end if;
  v_part := coalesce(array_length(public.votanti_partita(p_partita), 1), 0);
  select count(*) into v_voti from public.voti_mvp where partita_id = p_partita and votato_id is not null;
  if v_voti = 0 then
    update public.partite set mvp_stato = 'nessun_voto' where id = p_partita;
    return;
  end if;
  if v_voti * 2 < v_part then
    update public.partite set mvp_stato = 'non_valida' where id = p_partita;
    perform public.messaggio_sistema(p_partita,
      'Migliore in campo: votazione non valida, hanno votato ' || v_voti || ' su ' || v_part || ' (serve almeno la metà)');
    return;
  end if;
  select max(n) into v_max from (select count(*) n from public.voti_mvp where partita_id = p_partita and votato_id is not null group by votato_id) x;
  select array_agg(votato_id) into v_vincitori from (
    select votato_id from public.voti_mvp where partita_id = p_partita and votato_id is not null
    group by votato_id having count(*) = v_max) x;
  update public.partite set mvp_stato = 'valida', mvp_ids = v_vincitori where id = p_partita;
  update public.profili set coppe = coppe + 1 where id = any(v_vincitori);
  select string_agg(public.nome_breve(x), ' e ') into v_nomi from unnest(v_vincitori) x;
  perform public.messaggio_sistema(p_partita, 'Migliore in campo: ' || v_nomi || ' (' || v_max || ' voti su ' || v_voti || ')');
  begin
    perform public.invia_push(v_vincitori, 'Sei il migliore in campo!',
      'I compagni ti hanno votato migliore in campo · ' || public.descrivi_partita(p_partita) || '. Hai una coppa in più.', '/profilo');
  exception when others then null;
  end;
end $$;

-- voti facoltativi ai compagni (1-5 su 4 categorie), anonimi
create or replace function public.dai_voti(p_partita uuid, p_a uuid, p_puntualita int, p_correttezza int, p_livello int, p_squadra int)
returns void language plpgsql security definer set search_path = public as $$
declare p public.partite%rowtype;
begin
  select * into p from public.partite where id = p_partita;
  if p.id is null then raise exception 'Partita non trovata'; end if;
  if not (auth.uid() = any(public.votanti_partita(p_partita))) then raise exception 'Non hai partecipato a questa partita'; end if;
  if now() < public.fine_partita(p) then raise exception 'La partita non è ancora finita'; end if;
  if p_a = auth.uid() then raise exception 'Non puoi votare te stesso'; end if;
  if not exists (select 1 from public.posizioni where partita_id = p_partita and giocatore_id = p_a) then raise exception 'Puoi votare solo chi ha giocato'; end if;
  if least(p_puntualita, p_correttezza, p_livello, p_squadra) < 1 or greatest(p_puntualita, p_correttezza, p_livello, p_squadra) > 5 then
    raise exception 'I voti vanno da 1 a 5';
  end if;
  insert into public.recensioni (partita_id, da_id, a_id, puntualita, correttezza, livello, squadra)
  values (p_partita, auth.uid(), p_a, p_puntualita, p_correttezza, p_livello, p_squadra)
  on conflict (partita_id, da_id, a_id) do update set puntualita = excluded.puntualita, correttezza = excluded.correttezza,
    livello = excluded.livello, squadra = excluded.squadra;
end $$;

grant execute on function public.voti_da_dare(), public.vota_mvp(uuid, uuid),
  public.dai_voti(uuid, uuid, int, int, int, int) to authenticated;
revoke execute on function public.chiudi_votazione(uuid) from public, anon, authenticated;

-- stati aggiornati sulla durata; votazioni chiuse 24 ore dopo la fine
create or replace function public.aggiorna_stati_partite()
returns void language plpgsql security definer set search_path = public as $$
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
    where p.stato = 'giocata' and p.mvp_stato is null and now() >= public.fine_partita(p) + interval '24 hours'
  loop
    perform public.chiudi_votazione(v_id);
  end loop;

  update public.partite set archiviata = true, archiviata_il = now()
  where not archiviata and stato in ('giocata', 'annullata')
    and (data_ora at time zone 'Europe/Rome')::date < (now() at time zone 'Europe/Rome')::date;
end $$;

-- ---------------------------------------------------------------------
-- Amministratore: eliminare partite e campi (anche con partite), confermare i campi
-- ---------------------------------------------------------------------
create or replace function public.admin_elimina_partita(p_partita uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  delete from public.partite where id = p_partita;
end $$;

create or replace function public.admin_elimina_campo(p_campo uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  delete from public.partite where campo_id = p_campo;
  delete from public.campi where id = p_campo;
end $$;

create or replace function public.admin_verifica_campo(p_campo uuid, p_si boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  update public.campi set verificato = p_si where id = p_campo;
end $$;

grant execute on function public.admin_elimina_partita(uuid), public.admin_elimina_campo(uuid), public.admin_verifica_campo(uuid, boolean) to authenticated;
