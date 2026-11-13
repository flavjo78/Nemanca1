-- 0026: "Cercami per le partite" acceso di default (decisione di Flavio del 13/11). Rieseguibile.
-- Vale per i nuovi iscritti; gli iscritti attuali vengono accesi una volta sola
-- (ognuno può spegnerlo dalla Home).
alter table public.profili alter column cercami set default true;

create table if not exists public.migrazioni_una_tantum (nome text primary key, eseguita_il timestamptz not null default now());
alter table public.migrazioni_una_tantum enable row level security;
do $$
begin
  if not exists (select 1 from public.migrazioni_una_tantum where nome = '0026_cercami_acceso') then
    update public.profili set cercami = true where not cercami;
    insert into public.migrazioni_una_tantum (nome) values ('0026_cercami_acceso');
  end if;
end $$;
