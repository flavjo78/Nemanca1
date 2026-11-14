-- 0027: i km si possono contare "da questa posizione" (GPS del telefono, arrotondata a ~1 km)
-- invece che da un comune scelto. Rieseguibile.
alter table public.profili add column if not exists da_posizione boolean not null default false;
