-- =====================================================================
-- nome_breve: "Marco R." con nome e cognome, "Flavio" con un nome solo.
-- Prima un nome di una sola parola diventava "Un giocatore". Rieseguibile.
-- =====================================================================
create or replace function public.nome_breve(p_id uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select case
       when trim(coalesce(nome, '')) = '' then null
       when position(' ' in trim(nome)) = 0 then trim(nome)
       else split_part(trim(nome), ' ', 1) || ' ' || upper(left(split_part(trim(nome), ' ', 2), 1)) || '.'
     end
     from public.profili where id = p_id),
    'Un giocatore');
$$;

-- sistemo le card delle candidature già scritte con "Un giocatore"
update public.messaggi m
set testo = public.nome_breve(r.giocatore_id) || ' si candida' ||
            coalesce(' come ' || public.etichetta_ruolo(r.ruolo_richiesto), '')
from public.richieste r
where m.tipo = 'richiesta' and m.riferimento_id = r.id and m.testo like 'Un giocatore%';
