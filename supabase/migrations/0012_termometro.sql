-- =====================================================================
-- Termometro dello spazio per l'amministratore. Rieseguibile.
-- =====================================================================
create or replace function public.admin_spazio()
returns table (database_byte bigint, messaggi_byte bigint, partite_byte bigint, profili_byte bigint,
               messaggi bigint, partite bigint, profili bigint)
language sql stable security definer set search_path = public as $$
  select pg_database_size(current_database()),
         pg_total_relation_size('public.messaggi'),
         pg_total_relation_size('public.partite') + pg_total_relation_size('public.posizioni'),
         pg_total_relation_size('public.profili'),
         (select count(*) from public.messaggi),
         (select count(*) from public.partite),
         (select count(*) from public.profili)
  where public.e_admin();
$$;
grant execute on function public.admin_spazio() to authenticated;
