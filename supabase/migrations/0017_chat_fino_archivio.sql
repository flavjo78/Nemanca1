-- 0017: la chat resta aperta anche dopo la partita e si chiude solo quando
-- la partita va in archivio (il giorno dopo). Rieseguibile.

create or replace function public.chat_attiva(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.partite where id = p_partita and not archiviata);
$$;

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
         not p.archiviata
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
  order by (not p.archiviata) desc, coalesce(m.creato_il, p.creato_il) desc;
$$;
grant execute on function public.mie_chat() to authenticated;
