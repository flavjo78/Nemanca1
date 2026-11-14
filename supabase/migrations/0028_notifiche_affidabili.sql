-- 0028: notifiche più affidabili. Rieseguibile.
-- * priorità alta (Android in standby con l'app chiusa riceve subito) e scadenza di 24 ore;
-- * il percorso della pagina anche nei dati della notifica, così l'app apre la chat giusta
--   anche su iPhone (dove il tocco apre l'app ma non sempre la pagina indicata).

create or replace function public.invia_push(
  p_destinatari uuid[], p_titolo text, p_testo text, p_percorso text default '/', p_gruppo text default null
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_chiave text;
  v_dest text[];
  v_corpo jsonb;
begin
  select array_agg(distinct d::text) into v_dest
  from unnest(p_destinatari) d where d is not null;
  if v_dest is null or array_length(v_dest, 1) = 0 then return; end if;

  begin
    select decrypted_secret into v_chiave from vault.decrypted_secrets where name = 'onesignal_rest_key' limit 1;
  exception when others then v_chiave := null;
  end;
  if v_chiave is null or btrim(v_chiave) = '' then return; end if;

  v_corpo := jsonb_build_object(
    'app_id', '27506aa7-d2ae-4a62-8a47-56dad6193dd6',
    'target_channel', 'push',
    'include_aliases', jsonb_build_object('external_id', to_jsonb(v_dest)),
    'headings', jsonb_build_object('en', p_titolo, 'it', p_titolo),
    'contents', jsonb_build_object('en', left(p_testo, 300), 'it', left(p_testo, 300)),
    'url', 'https://www.nemanca1.com' || coalesce(p_percorso, '/'),
    -- il percorso anche nei dati: l'app lo usa per aprire la pagina giusta (serve su iPhone)
    'data', jsonb_build_object('percorso', coalesce(p_percorso, '/')),
    -- priorità alta: su Android arriva subito anche con il telefono in standby e l'app chiusa
    'priority', 10,
    'ttl', 86400
  );
  if p_gruppo is not null then
    v_corpo := v_corpo || jsonb_build_object('web_push_topic', p_gruppo);
  end if;

  begin
    perform net.http_post(
      url := 'https://api.onesignal.com/notifications?c=push',
      body := v_corpo,
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Key ' || btrim(v_chiave))
    );
  exception when others then
    raise warning 'invia_push: %', sqlerrm;
  end;
end $$;
revoke execute on function public.invia_push(uuid[], text, text, text, text) from public, anon, authenticated;
