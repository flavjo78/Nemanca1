-- 0032: l'amministratore può "entrare come" un utente (per i test) e creare giocatori di prova.
-- Il database chiama le API di amministrazione di Supabase Auth con la chiave segreta
-- salvata nel Vault come 'supabase_secret_key' (mai nel codice). Ogni accesso è registrato.
-- Rieseguibile.

alter table public.profili add column if not exists di_prova boolean not null default false;

create table if not exists public.admin_accessi (
  id bigserial primary key,
  admin_id uuid not null,
  utente_id uuid not null,
  creato_il timestamptz not null default now()
);
alter table public.admin_accessi enable row level security;

-- chiamata alle API di Auth (asincrona: restituisce il numero della richiesta)
create or replace function public.admin_chiama_auth(p_percorso text, p_corpo jsonb)
returns bigint language plpgsql security definer set search_path = public as $$
declare v_chiave text; v_intest jsonb;
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  begin
    select btrim(decrypted_secret) into v_chiave from vault.decrypted_secrets where name = 'supabase_secret_key' limit 1;
  exception when others then v_chiave := null;
  end;
  if v_chiave is null or v_chiave = '' then
    raise exception 'Manca la chiave segreta di Supabase nel Vault (supabase_secret_key)';
  end if;
  v_intest := jsonb_build_object('Content-Type', 'application/json', 'apikey', v_chiave);
  if v_chiave like 'eyJ%' then v_intest := v_intest || jsonb_build_object('Authorization', 'Bearer ' || v_chiave); end if;
  return net.http_post(url := 'https://vplzkjxgikpxewxkzanz.supabase.co/auth/v1/' || p_percorso, body := p_corpo, headers := v_intest);
end $$;
revoke execute on function public.admin_chiama_auth(text, jsonb) from public, anon, authenticated;

-- entra come un utente: chiede un codice d'accesso usa-e-getta per la sua email
create or replace function public.admin_entra_come(p_utente uuid)
returns bigint language plpgsql security definer set search_path = public as $$
declare v_email text;
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  select email into v_email from auth.users where id = p_utente;
  if v_email is null then raise exception 'Utente non trovato'; end if;
  insert into public.admin_accessi (admin_id, utente_id) values (auth.uid(), p_utente);
  return public.admin_chiama_auth('admin/generate_link', jsonb_build_object('type', 'magiclink', 'email', v_email));
end $$;

-- crea un giocatore di prova (email finta @nemanca1.com, nessuno la riceve)
create or replace function public.admin_crea_prova()
returns bigint language plpgsql security definer set search_path = public as $$
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  return public.admin_chiama_auth('admin/users', jsonb_build_object(
    'email', 'prova-' || substr(md5(random()::text), 1, 8) || '@nemanca1.com', 'email_confirm', true));
end $$;

-- risposta di una richiesta: solo i campi che servono all'app
create or replace function public.admin_esito(p_richiesta bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r record; c jsonb;
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  select status_code, content, error_msg into r from net._http_response where id = p_richiesta;
  if not found then return jsonb_build_object('pronto', false); end if;
  begin c := r.content::jsonb; exception when others then c := '{}'::jsonb; end;
  if r.status_code between 200 and 299 then
    return jsonb_build_object('pronto', true, 'ok', true,
      'email', coalesce(c->>'email', c->'user'->>'email'),
      'id', coalesce(c->>'id', c->'user'->>'id'),
      'codice', coalesce(c->>'email_otp', c->'properties'->>'email_otp'));
  end if;
  return jsonb_build_object('pronto', true, 'ok', false,
    'errore', coalesce(c->>'msg', c->>'message', c->>'error_description', r.error_msg, 'Errore ' || r.status_code));
end $$;

-- nome e ruoli del giocatore di prova appena creato
create or replace function public.admin_imposta_prova(p_utente uuid, p_nome text, p_ruoli text[] default '{}')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.e_admin() then raise exception 'Solo l''amministratore'; end if;
  insert into public.profili (id, nome, ruoli_preferiti, di_prova) values (p_utente, btrim(p_nome), coalesce(p_ruoli, '{}'), true)
  on conflict (id) do update set nome = excluded.nome, ruoli_preferiti = excluded.ruoli_preferiti, di_prova = true;
end $$;

grant execute on function public.admin_entra_come(uuid), public.admin_crea_prova(), public.admin_esito(bigint),
  public.admin_imposta_prova(uuid, text, text[]) to authenticated;

-- i giocatori di prova non fanno partire l'avviso "nuovo iscritto"
create or replace function public.push_nuovo_iscritto()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.nome is not null and btrim(new.nome) <> '' and not new.di_prova
       and (tg_op = 'INSERT' or old.nome is null or btrim(old.nome) = '') then
      perform public.invia_push(
        array(select id from public.profili where admin and id <> new.id),
        'Nuovo iscritto', new.nome || coalesce(' · ' || new.comune, '') || ' si è iscritto a Ne manca 1', '/admin');
    end if;
  exception when others then raise warning 'push_nuovo_iscritto: %', sqlerrm;
  end;
  return new;
end $$;
