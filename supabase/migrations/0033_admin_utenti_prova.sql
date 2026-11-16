-- 0033: l'elenco iscritti dell'amministratore dice anche chi è un giocatore di prova. Rieseguibile.
drop function if exists public.admin_utenti(int);
create or replace function public.admin_utenti(p_limite int default 50)
returns table (id uuid, nome text, comune text, email text, creato_il timestamptz, ultimo_accesso timestamptz, admin boolean, di_prova boolean)
language sql stable security definer set search_path = public as $$
  select p.id, p.nome, p.comune, u.email::text, p.creato_il, u.last_sign_in_at, p.admin, p.di_prova
  from public.profili p join auth.users u on u.id = p.id
  where public.e_admin()
  order by p.di_prova, p.creato_il desc
  limit p_limite;
$$;
grant execute on function public.admin_utenti(int) to authenticated;
