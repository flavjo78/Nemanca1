-- 0034: le funzioni dell'amministratore non si possono nemmeno chiamare senza accesso
-- (dentro controllano comunque che chi chiama sia amministratore). Rieseguibile.
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as firma, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'
  loop
    execute format('revoke execute on function %s from public, anon', f.firma);
    if f.proname = 'admin_chiama_auth' then
      execute format('revoke execute on function %s from authenticated', f.firma);
    else
      execute format('grant execute on function %s to authenticated', f.firma);
    end if;
  end loop;
end $$;
