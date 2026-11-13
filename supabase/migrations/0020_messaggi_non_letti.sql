-- 0020: messaggi da leggere, salvati nel database (valgono su tutti i dispositivi). Rieseguibile.
create table if not exists public.letture (
  utente_id uuid not null references public.profili(id) on delete cascade,
  partita_id uuid not null references public.partite(id) on delete cascade,
  letto_il timestamptz not null default now(),
  primary key (utente_id, partita_id)
);
alter table public.letture enable row level security;
drop policy if exists "letture proprie" on public.letture;
create policy "letture proprie" on public.letture for select to authenticated using (utente_id = auth.uid());

-- segna come letta la chat di una partita (fino ad adesso)
create or replace function public.segna_letto(p_partita uuid)
returns void language sql security definer set search_path = public as $$
  insert into public.letture (utente_id, partita_id, letto_il)
  select auth.uid(), p_partita, now() where auth.uid() is not null
  on conflict (utente_id, partita_id) do update set letto_il = excluded.letto_il;
$$;
grant execute on function public.segna_letto(uuid) to authenticated;

-- messaggi da leggere per ogni mia chat ancora aperta (escludo i miei)
create or replace function public.non_letti()
returns table (partita_id uuid, quanti bigint)
language sql stable security definer set search_path = public as $$
  select m.partita_id, count(*)
  from public.messaggi m
  join public.partite p on p.id = m.partita_id and not p.archiviata
  left join public.letture l on l.partita_id = m.partita_id and l.utente_id = auth.uid()
  where auth.uid() is not null
    and m.autore_id is distinct from auth.uid()
    and m.creato_il > coalesce(l.letto_il, '-infinity'::timestamptz)
    and (p.organizzatore_id = auth.uid()
      or exists (select 1 from public.posizioni po where po.partita_id = p.id and po.giocatore_id = auth.uid())
      or exists (select 1 from public.tribuna t where t.partita_id = p.id and t.giocatore_id = auth.uid())
      or exists (select 1 from public.vice v where v.partita_id = p.id and v.giocatore_id = auth.uid()))
  group by m.partita_id;
$$;
grant execute on function public.non_letti() to authenticated;

-- chi ha già aperto le chat finora parte "in pari": niente valanga di vecchi messaggi da leggere
insert into public.letture (utente_id, partita_id, letto_il)
select distinct x.utente, x.partita, now() from (
  select organizzatore_id as utente, id as partita from public.partite
  union select giocatore_id, partita_id from public.posizioni where giocatore_id is not null
  union select giocatore_id, partita_id from public.tribuna
  union select giocatore_id, partita_id from public.vice
) x
where not exists (select 1 from public.letture l where l.utente_id = x.utente and l.partita_id = x.partita)
  and exists (select 1 from public.profili pr where pr.id = x.utente);
