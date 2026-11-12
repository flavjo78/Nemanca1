-- 0015: il nome del profilo si sceglie una volta sola.
-- Dopo il primo salvataggio l'utente non può più cambiarlo (evita che la stessa
-- mail cambi identità spesso). Può correggerlo solo l'amministratore, oppure
-- un intervento diretto sul database (auth.uid() nullo).

create or replace function public.blocca_cambio_nome()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.nome is not null and btrim(old.nome) <> ''
     and new.nome is distinct from old.nome
     and auth.uid() is not null
     and not public.e_admin() then
    raise exception 'Il nome non si può cambiare. Se è sbagliato scrivi a supporto@nemanca1.com';
  end if;
  return new;
end;
$$;

drop trigger if exists profili_blocca_nome on public.profili;
create trigger profili_blocca_nome
  before update of nome on public.profili
  for each row execute function public.blocca_cambio_nome();
