-- =====================================================================
-- Candidatura con preferenza di squadra (A, B o qualsiasi). Rieseguibile.
-- Accettando, si cerca prima un posto nella squadra preferita, poi nell'altra.
-- =====================================================================
alter table public.richieste add column if not exists squadra_preferita char(1);
alter table public.richieste drop constraint if exists richieste_squadra_preferita_check;
alter table public.richieste add constraint richieste_squadra_preferita_check check (squadra_preferita in ('A','B'));

drop function if exists public.candidati(uuid, text);
create or replace function public.candidati(p_partita uuid, p_ruolo text default null, p_squadra char default null)
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
  insert into public.richieste (partita_id, giocatore_id, ruolo_richiesto, squadra_preferita)
  values (p_partita, auth.uid(), p_ruolo, nullif(p_squadra, ''))
  returning id into v_id;
  perform public.messaggio_sistema(p_partita,
    public.nome_breve(auth.uid()) || ' si candida' || coalesce(' come ' || public.etichetta_ruolo(p_ruolo), '')
      || coalesce(' · squadra ' || nullif(p_squadra, ''), ''), 'richiesta', v_id);
  return v_id;
end $$;
grant execute on function public.candidati(uuid, text, char) to authenticated;

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

  -- ordine: squadra preferita prima, poi posti in campo prima della panchina, porta solo se richiesta, poi la squadra con meno giocatori
  select p.id into v_pos from public.posizioni p
  where p.partita_id = v_r.partita_id and p.stato = 'libera'
    and (v_r.ruolo_richiesto is null or p.ruolo = v_r.ruolo_richiesto)
  order by (v_r.squadra_preferita is not null and p.squadra <> v_r.squadra_preferita),
           (p.ruolo = 'panchina'),
           (v_r.ruolo_richiesto is null and p.ruolo = 'portiere'),   -- chi non sceglie il ruolo va in porta solo se non c'è altro
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
  perform public.messaggio_sistema(v_r.partita_id,
    public.nome_breve(v_r.giocatore_id) || ' è stato accettato: ' ||
    (select public.etichetta_ruolo(ruolo) || ' (squadra ' || squadra || ')' from public.posizioni where id = v_pos));
end $$;
