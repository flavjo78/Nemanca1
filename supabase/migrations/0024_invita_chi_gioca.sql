-- 0024: può invitare amici anche chi gioca nella partita, non solo l'organizzatore. Rieseguibile.
-- Nelle partite "decido io chi gioca", l'invito di un giocatore accettato diventa una candidatura
-- che l'organizzatore approva (nella squadra di chi ha invitato, se possibile).

create or replace function public.invita_amici(p_partita uuid, p_amici uuid[])
returns int language plpgsql security definer set search_path = public as $$
declare v_amico uuid; v_n int := 0; v_nomi text[] := '{}';
begin
  if not (public.e_organizzatore(p_partita)
          or exists (select 1 from public.posizioni where partita_id = p_partita and giocatore_id = auth.uid())) then
    raise exception 'Può invitare solo chi organizza o gioca in questa partita';
  end if;
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
    perform public.messaggio_sistema(p_partita,
      case when public.e_organizzatore(p_partita) and exists (select 1 from public.partite where id = p_partita and organizzatore_id = auth.uid())
           then 'L''organizzatore' else public.nome_breve(auth.uid()) end
      || ' ha invitato ' || array_to_string(v_nomi, ', '));
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
  elsif exists (select 1 from public.partite p where p.id = p_partita and p.modalita = 'approvazione'
                and p.organizzatore_id <> v_inv.da_id
                and not exists (select 1 from public.vice v where v.partita_id = p.id and v.giocatore_id = v_inv.da_id)) then
    -- invito di un giocatore in una partita dove decide l'organizzatore: diventa una candidatura da approvare
    update public.inviti set stato = 'accettato', aggiornato_il = now() where id = v_inv.id;
    if not exists (select 1 from public.richieste where partita_id = p_partita and giocatore_id = auth.uid() and stato = 'in_attesa') then
      insert into public.richieste (partita_id, giocatore_id, ruolo_richiesto, stato, squadra_preferita)
      values (p_partita, auth.uid(), null, 'in_attesa',
              (select squadra from public.posizioni where partita_id = p_partita and giocatore_id = v_inv.da_id limit 1));
      perform public.messaggio_sistema(p_partita,
        public.nome_breve(auth.uid()) || ' vuole giocare su invito di ' || public.nome_breve(v_inv.da_id) || ': decide l''organizzatore');
    end if;
    return;
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

