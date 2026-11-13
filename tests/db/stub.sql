-- Finto ambiente Supabase per provare le migrazioni su un Postgres vuoto
-- (in locale e nei controlli automatici di GitHub). Non va mai eseguito sul database vero.
create schema if not exists auth;
create schema if not exists extensions;
create table if not exists auth.users (id uuid primary key, email text, created_at timestamptz default now(), last_sign_in_at timestamptz, raw_user_meta_data jsonb);
create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::json ->> 'sub'
  )::uuid
$$;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then create publication supabase_realtime; end if;
end $$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
