-- 0030: le email d'invito partono da invito@nemanca1.com (deciso da Flavio il 16/11).
-- Il dominio è verificato su Resend: non serve una casella vera; le risposte vanno a supporto@. Rieseguibile.

create or replace function public.invia_email(p_a uuid, p_oggetto text, p_html text, p_testo text)
returns void language plpgsql security definer set search_path = public as $$
declare v_chiave text; v_email text;
begin
  select email into v_email from auth.users where id = p_a;
  if v_email is null then return; end if;
  begin
    select decrypted_secret into v_chiave from vault.decrypted_secrets where name = 'resend_api_key' limit 1;
  exception when others then v_chiave := null;
  end;
  if v_chiave is null or btrim(v_chiave) = '' then return; end if;
  begin
    perform net.http_post(
      url := 'https://api.resend.com/emails',
      body := jsonb_build_object(
        'from', 'Ne manca 1 <invito@nemanca1.com>',
        'to', jsonb_build_array(v_email),
        'reply_to', 'supporto@nemanca1.com',
        'subject', p_oggetto,
        'html', p_html,
        'text', p_testo),
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || btrim(v_chiave))
    );
  exception when others then raise warning 'invia_email: %', sqlerrm;
  end;
end $$;
revoke execute on function public.invia_email(uuid, text, text, text) from public, anon, authenticated;
