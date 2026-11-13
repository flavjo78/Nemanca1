-- 0019: Tappa 4, primo passo. Rieseguibile.
-- * raggio_km: fino a quanti km il giocatore è disposto ad andare a giocare (lo sceglie lui, 1-100);
-- * cercami: se acceso, il giocatore può comparire nelle ricerche "giocatori vicini" (spento finché non lo accende).
alter table public.profili add column if not exists raggio_km smallint not null default 20;
alter table public.profili add column if not exists cercami boolean not null default false;
alter table public.profili drop constraint if exists profili_raggio_km_valido;
alter table public.profili add constraint profili_raggio_km_valido check (raggio_km between 1 and 100);
