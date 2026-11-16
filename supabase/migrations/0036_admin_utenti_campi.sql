-- 0036: l'amministratore elimina utenti e modifica i campi (nome, indirizzo, posizione). Rieseguibile.

-- elimina un utente: libera i suoi posti, poi cancella l'account (a cascata profilo, amicizie, liste...;
-- le partite che organizzava vengono eliminate). Non si può eliminare un amministratore né se stessi.
create or replace function public.admin_elimina_utente(p_utente uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  if p_utente = auth.uid() then raise exception 'Non puoi eliminare il tuo account da qui'; end if;
  if exists (select 1 from public.profili where id = p_utente and admin) then raise exception 'Non si può eliminare un amministratore'; end if;
  update public.posizioni set stato = 'libera', giocatore_id = null, nuovo_ruolo_proposto = null where giocatore_id = p_utente;
  delete from public.tribuna where giocatore_id = p_utente;
  delete from auth.users where id = p_utente;
end $$;

create or replace function public.admin_modifica_campo(p_campo uuid, p_nome text, p_indirizzo text, p_lat double precision, p_lng double precision)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  if char_length(btrim(coalesce(p_nome, ''))) = 0 then raise exception 'Il nome del campo non può essere vuoto'; end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'Posizione non valida'; end if;
  update public.campi set nome = btrim(p_nome), indirizzo = coalesce(btrim(p_indirizzo), indirizzo), lat = p_lat, lng = p_lng where id = p_campo;
  if not found then raise exception 'Campo non trovato'; end if;
end $$;

revoke execute on function public.admin_elimina_utente(uuid), public.admin_modifica_campo(uuid, text, text, double precision, double precision) from public, anon;
grant execute on function public.admin_elimina_utente(uuid), public.admin_modifica_campo(uuid, text, text, double precision, double precision) to authenticated;
