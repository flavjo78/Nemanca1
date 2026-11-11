-- =====================================================================
-- Tappa 3 – chat della partita. Rieseguibile.
-- Chi partecipa (organizzatore, vice, giocatori, panchina, tribuna) legge e scrive.
-- =====================================================================

-- messaggi di testo: tra 1 e 1000 caratteri
alter table public.messaggi drop constraint if exists messaggi_testo_lunghezza;
alter table public.messaggi add constraint messaggi_testo_lunghezza check (char_length(testo) between 1 and 1000);

-- partecipa: anche i vice (già inclusi in e_organizzatore) e chi ha un invito in corso
create or replace function public.partecipa(p_partita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.e_organizzatore(p_partita)
      or exists (select 1 from public.posizioni where partita_id = p_partita and giocatore_id = auth.uid())
      or exists (select 1 from public.tribuna where partita_id = p_partita and giocatore_id = auth.uid())
      or exists (select 1 from public.inviti where partita_id = p_partita and a_id = auth.uid() and stato = 'in_attesa');
$$;

-- l'autore di un messaggio di testo deve essere chi scrive; i messaggi di sistema li crea solo il DB
drop policy if exists "messaggi insert" on public.messaggi;
create policy "messaggi insert" on public.messaggi for insert to authenticated
  with check (autore_id = auth.uid() and tipo = 'testo' and public.partecipa(partita_id));

-- elenco delle mie chat con l'ultimo messaggio
create or replace function public.mie_chat()
returns table (
  partita_id uuid, data_ora timestamptz, formato smallint, stato text, campo_nome text,
  ultimo_testo text, ultimo_tipo text, ultimo_autore text, ultimo_il timestamptz, messaggi bigint
) language sql stable security definer set search_path = public as $$
  select p.id, p.data_ora, p.formato, p.stato, c.nome,
         m.testo, m.tipo, pr.nome, m.creato_il,
         (select count(*) from public.messaggi x where x.partita_id = p.id)
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
    and p.data_ora > now() - interval '14 days'
  order by coalesce(m.creato_il, p.creato_il) desc;
$$;
grant execute on function public.mie_chat() to authenticated;
