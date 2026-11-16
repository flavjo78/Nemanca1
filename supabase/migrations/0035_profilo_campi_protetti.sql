-- 0035: campi del profilo che l'utente NON può cambiare da solo (sicurezza). Rieseguibile.
-- Prima un utente, chiamando le API direttamente, poteva darsi admin = true o delle coppe.
-- Ora, se la modifica arriva dall'app (ruolo "authenticated"/"anon"), admin, coppe e di_prova
-- restano quelli di prima (nuovo profilo: admin falso, 0 coppe, non di prova).
-- Le funzioni del database (amministratore, votazioni) girano come proprietario e possono cambiarli.
create or replace function public.profili_campi_protetti()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      new.admin := false;
      new.coppe := 0;
      new.di_prova := false;
    else
      new.admin := old.admin;
      new.coppe := old.coppe;
      new.di_prova := old.di_prova;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists profili_campi_protetti on public.profili;
create trigger profili_campi_protetti before insert or update on public.profili
  for each row execute function public.profili_campi_protetti();
