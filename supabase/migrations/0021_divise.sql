-- 0021: divise delle squadre (colore di maglia e pantaloncini), scelte dall'organizzatore
-- (o dal vice per la sua squadra). Rieseguibile.
alter table public.partite add column if not exists divise jsonb not null
  default '{"A":{"maglia":"bianco","pantaloncini":"nero"},"B":{"maglia":"blu","pantaloncini":"blu"}}'::jsonb;

create or replace function public.colori_divise()
returns text[] language sql immutable as $$
  select array['bianco','nero','grigio','rosso','granata','arancione','giallo','verde','azzurro','blu','viola','rosa'];
$$;

create or replace function public.nome_colore(p_colore text, p_plurale boolean)
returns text language sql immutable as $$
  select case p_colore
    when 'bianco' then case when p_plurale then 'bianchi' else 'bianca' end
    when 'nero' then case when p_plurale then 'neri' else 'nera' end
    when 'grigio' then case when p_plurale then 'grigi' else 'grigia' end
    when 'rosso' then case when p_plurale then 'rossi' else 'rossa' end
    when 'giallo' then case when p_plurale then 'gialli' else 'gialla' end
    when 'azzurro' then case when p_plurale then 'azzurri' else 'azzurra' end
    when 'arancione' then case when p_plurale then 'arancioni' else 'arancione' end
    when 'verde' then case when p_plurale then 'verdi' else 'verde' end
    else p_colore end;
$$;

create or replace function public.imposta_divisa(p_partita uuid, p_squadra char, p_maglia text, p_pantaloncini text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_squadra not in ('A', 'B') then raise exception 'Squadra non valida'; end if;
  if not public.puo_gestire_squadra(p_partita, p_squadra) then raise exception 'Solo l''organizzatore o il vice della squadra può scegliere la divisa'; end if;
  if not public.partita_modificabile(p_partita) then raise exception 'La partita non si può più modificare'; end if;
  if not (p_maglia = any(public.colori_divise()) and p_pantaloncini = any(public.colori_divise())) then
    raise exception 'Colore non valido';
  end if;
  update public.partite
  set divise = jsonb_set(coalesce(divise, '{}'::jsonb), array[p_squadra::text],
                         jsonb_build_object('maglia', p_maglia, 'pantaloncini', p_pantaloncini))
  where id = p_partita;
  perform public.messaggio_sistema(p_partita,
    'Squadra ' || p_squadra || ': maglia ' || public.nome_colore(p_maglia, false) || ' e pantaloncini ' || public.nome_colore(p_pantaloncini, true));
end $$;
grant execute on function public.imposta_divisa(uuid, char, text, text) to authenticated;
