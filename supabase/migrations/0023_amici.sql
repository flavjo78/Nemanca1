-- 0023: lista amici. Si diventa amici solo se l'altro accetta; l'organizzatore può poi
-- invitare direttamente uno o tutti gli amici a una partita. Rieseguibile.

create table if not exists public.amicizie (
  id uuid primary key default gen_random_uuid(),
  da_id uuid not null references public.profili(id) on delete cascade,
  a_id uuid not null references public.profili(id) on delete cascade,
  stato text not null default 'in_attesa' check (stato in ('in_attesa', 'accettata', 'rifiutata')),
  creato_il timestamptz not null default now(),
  risposto_il timestamptz,
  check (da_id <> a_id)
);
-- una sola amicizia per coppia, in qualunque verso
create unique index if not exists amicizie_coppia on public.amicizie (least(da_id, a_id), greatest(da_id, a_id));
alter table public.amicizie enable row level security;
drop policy if exists "amicizie mie" on public.amicizie;
create policy "amicizie mie" on public.amicizie for select to authenticated using (da_id = auth.uid() or a_id = auth.uid());

create or replace function public.sono_amici(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.amicizie
                 where stato = 'accettata' and least(da_id, a_id) = least(p_a, p_b) and greatest(da_id, a_id) = greatest(p_a, p_b));
$$;

-- chiedi l'amicizia (se l'altro te l'aveva già chiesta, diventate subito amici)
create or replace function public.chiedi_amicizia(p_altro uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v public.amicizie%rowtype;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  if p_altro = auth.uid() then raise exception 'Non puoi aggiungere te stesso'; end if;
  if not exists (select 1 from public.profili where id = p_altro) then raise exception 'Giocatore non trovato'; end if;
  select * into v from public.amicizie
  where least(da_id, a_id) = least(auth.uid(), p_altro) and greatest(da_id, a_id) = greatest(auth.uid(), p_altro) for update;
  if v.id is null then
    insert into public.amicizie (da_id, a_id) values (auth.uid(), p_altro);
    return 'inviata';
  elsif v.stato = 'accettata' then
    return 'gia_amici';
  elsif v.stato = 'in_attesa' and v.a_id = auth.uid() then
    update public.amicizie set stato = 'accettata', risposto_il = now() where id = v.id;
    return 'accettata';
  else
    -- richiesta rifiutata in passato o già inviata: la si rimanda
    update public.amicizie set da_id = auth.uid(), a_id = p_altro, stato = 'in_attesa', creato_il = now(), risposto_il = null where id = v.id;
    return 'inviata';
  end if;
end $$;

create or replace function public.rispondi_amicizia(p_amicizia uuid, p_accetta boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.amicizie set stato = case when p_accetta then 'accettata' else 'rifiutata' end, risposto_il = now()
  where id = p_amicizia and a_id = auth.uid() and stato = 'in_attesa';
  if not found then raise exception 'Richiesta non trovata'; end if;
end $$;

-- togli dagli amici (o annulla una richiesta inviata)
create or replace function public.togli_amicizia(p_altro uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.amicizie
  where least(da_id, a_id) = least(auth.uid(), p_altro) and greatest(da_id, a_id) = greatest(auth.uid(), p_altro)
    and (stato <> 'rifiutata' or da_id = auth.uid());
$$;

-- amici, richieste ricevute e inviate
create or replace function public.miei_amici()
returns table (amicizia_id uuid, id uuid, nome text, iniziali text, foto_url text, comune text, ruoli_preferiti text[], stato text)
language sql stable security definer set search_path = public as $$
  select a.id, p.id, p.nome, p.iniziali, p.foto_url, p.comune, p.ruoli_preferiti,
         case when a.stato = 'accettata' then 'amico' when a.a_id = auth.uid() then 'ricevuta' else 'inviata' end
  from public.amicizie a
  join public.profili p on p.id = case when a.da_id = auth.uid() then a.a_id else a.da_id end
  where auth.uid() is not null and (a.da_id = auth.uid() or a.a_id = auth.uid()) and a.stato in ('in_attesa', 'accettata')
  order by 8, p.nome;
$$;

-- cerca giocatori per nome (minimo 3 lettere); mostra solo nome, foto e comune
create or replace function public.cerca_giocatori(p_testo text)
returns table (id uuid, nome text, iniziali text, foto_url text, comune text, stato text)
language sql stable security definer set search_path = public as $$
  select p.id, p.nome, p.iniziali, p.foto_url, p.comune,
         (select case when a.stato = 'accettata' then 'amico' when a.stato = 'in_attesa' and a.a_id = auth.uid() then 'ricevuta'
                      when a.stato = 'in_attesa' then 'inviata' end
          from public.amicizie a
          where least(a.da_id, a.a_id) = least(auth.uid(), p.id) and greatest(a.da_id, a.a_id) = greatest(auth.uid(), p.id))
  from public.profili p
  where auth.uid() is not null and p.id <> auth.uid() and p.nome is not null
    and char_length(btrim(p_testo)) >= 3 and p.nome ilike '%' || btrim(p_testo) || '%'
  order by p.nome
  limit 20;
$$;

-- chi ha giocato con me (suggerimenti per la lista amici)
create or replace function public.compagni_di_gioco()
returns table (id uuid, nome text, iniziali text, foto_url text, comune text, partite bigint, stato text)
language sql stable security definer set search_path = public as $$
  with mie as (
    select partita_id from public.posizioni where giocatore_id = auth.uid()
    union select id from public.partite where organizzatore_id = auth.uid()
  ), loro as (
    select po.giocatore_id as id, count(distinct po.partita_id) as n
    from public.posizioni po join mie on mie.partita_id = po.partita_id
    where po.giocatore_id is not null and po.giocatore_id <> auth.uid()
    group by po.giocatore_id
  )
  select p.id, p.nome, p.iniziali, p.foto_url, p.comune, loro.n,
         (select case when a.stato = 'accettata' then 'amico' when a.stato = 'in_attesa' and a.a_id = auth.uid() then 'ricevuta'
                      when a.stato = 'in_attesa' then 'inviata' end
          from public.amicizie a
          where least(a.da_id, a.a_id) = least(auth.uid(), p.id) and greatest(a.da_id, a.a_id) = greatest(auth.uid(), p.id))
  from loro join public.profili p on p.id = loro.id
  where auth.uid() is not null
  order by loro.n desc, p.nome
  limit 30;
$$;

-- invita amici a una partita: l'invito non è legato a un posto preciso;
-- chi accetta viene messo nel primo posto libero adatto (prima i suoi ruoli, poi il campo, poi la panchina)
create or replace function public.invita_amici(p_partita uuid, p_amici uuid[])
returns int language plpgsql security definer set search_path = public as $$
declare v_amico uuid; v_n int := 0; v_nomi text[] := '{}';
begin
  if not public.e_organizzatore(p_partita) then raise exception 'Solo l''organizzatore può invitare'; end if;
  if not public.partita_modificabile(p_partita) then raise exception 'La partita non si può più modificare'; end if;
  foreach v_amico in array coalesce(p_amici, '{}') loop
    continue when not public.sono_amici(auth.uid(), v_amico);
    continue when exists (select 1 from public.posizioni where partita_id = p_partita and giocatore_id = v_amico);
    insert into public.inviti (partita_id, da_id, a_id, posizione_id, stato, aggiornato_il)
    values (p_partita, auth.uid(), v_amico, null, 'in_attesa', now())
    on conflict (partita_id, a_id) do update set posizione_id = null, stato = 'in_attesa', da_id = excluded.da_id, aggiornato_il = now();
    insert into public.tribuna (partita_id, giocatore_id) values (p_partita, v_amico) on conflict do nothing;
    v_n := v_n + 1;
    v_nomi := v_nomi || public.nome_breve(v_amico);
  end loop;
  if v_n > 0 then
    perform public.messaggio_sistema(p_partita, 'L''organizzatore ha invitato ' || array_to_string(v_nomi, ', '));
  end if;
  return v_n;
end $$;

create or replace function public.rispondi_invito(p_partita uuid, p_accetta boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_inv public.inviti%rowtype; v_pos public.posizioni%rowtype; v_mio uuid; v_ruoli text[];
begin
  select * into v_inv from public.inviti where partita_id = p_partita and a_id = auth.uid() and stato = 'in_attesa' for update;
  if v_inv.id is null then raise exception 'Nessuna richiesta in sospeso'; end if;
  if not p_accetta then
    update public.inviti set stato = 'rifiutato', aggiornato_il = now() where id = v_inv.id;
    perform public.messaggio_sistema(p_partita, public.nome_breve(auth.uid()) || ' per ora resta in tribuna');
    return;
  end if;
  if v_inv.posizione_id is not null then
    select * into v_pos from public.posizioni where id = v_inv.posizione_id for update;
    if v_pos.id is null or v_pos.stato <> 'libera' then
      update public.inviti set stato = 'rifiutato', aggiornato_il = now() where id = v_inv.id;
      raise exception 'Nel frattempo il posto è stato preso: chiedi all''organizzatore';
    end if;
  else
    -- invito senza posto: il primo libero adatto
    select coalesce(ruoli_preferiti, '{}') into v_ruoli from public.profili where id = auth.uid();
    select * into v_pos from public.posizioni
    where partita_id = p_partita and stato = 'libera'
    order by (ruolo = 'panchina'), (ruolo = any(v_ruoli)) desc, (ruolo = 'portiere' and not ('portiere' = any(v_ruoli))), random()
    limit 1 for update skip locked;
    if v_pos.id is null then raise exception 'Non ci sono più posti liberi: resti in tribuna'; end if;
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

grant execute on function public.chiedi_amicizia(uuid), public.rispondi_amicizia(uuid, boolean), public.togli_amicizia(uuid),
  public.miei_amici(), public.cerca_giocatori(text), public.compagni_di_gioco(), public.invita_amici(uuid, uuid[]) to authenticated;

-- notifiche: richiesta di amicizia e amicizia accettata
create or replace function public.push_amicizie()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.stato = 'in_attesa' and (tg_op = 'INSERT' or old.stato is distinct from 'in_attesa' or old.da_id <> new.da_id) then
      perform public.invia_push(array[new.a_id], 'Richiesta di amicizia',
        public.nome_breve(new.da_id) || ' vuole aggiungerti agli amici su Ne manca 1', '/amici');
    elsif tg_op = 'UPDATE' and new.stato = 'accettata' and old.stato = 'in_attesa' then
      perform public.invia_push(array[new.da_id], 'Nuovo amico',
        public.nome_breve(new.a_id) || ' ha accettato: ora puoi invitarlo alle tue partite', '/amici');
    end if;
  exception when others then raise warning 'push_amicizie: %', sqlerrm;
  end;
  return new;
end $$;
drop trigger if exists trg_push_amicizie on public.amicizie;
create trigger trg_push_amicizie after insert or update on public.amicizie
  for each row execute function public.push_amicizie();
