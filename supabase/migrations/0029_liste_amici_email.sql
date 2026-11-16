-- 0029: amici senza conferma, amici automatici tra chi gioca insieme, liste di giocatori,
-- email con il link alla partita quando si viene invitati. Rieseguibile.

-- ---------------------------------------------------------------------
-- Amici: niente conferma (deciso da Flavio il 16/11)
-- ---------------------------------------------------------------------
update public.amicizie set stato = 'accettata', risposto_il = coalesce(risposto_il, now()) where stato = 'in_attesa';

create or replace function public.chiedi_amicizia(p_altro uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v public.amicizie%rowtype;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  if p_altro = auth.uid() then raise exception 'Non puoi aggiungere te stesso'; end if;
  if not exists (select 1 from public.profili where id = p_altro) then raise exception 'Giocatore non trovato'; end if;
  select * into v from public.amicizie
  where least(da_id, a_id) = least(auth.uid(), p_altro) and greatest(da_id, a_id) = greatest(auth.uid(), p_altro) for update;
  if v.id is not null and v.stato = 'accettata' then return 'gia_amici'; end if;
  if v.id is null then
    insert into public.amicizie (da_id, a_id, stato, risposto_il) values (auth.uid(), p_altro, 'accettata', now());
  else
    update public.amicizie set da_id = auth.uid(), a_id = p_altro, stato = 'accettata', risposto_il = now() where id = v.id;
  end if;
  return 'accettata';
end $$;

-- chi gioca nella stessa partita diventa amico (senza notifiche: succede in automatico)
create or replace function public.amici_dalla_partita(p_partita uuid)
returns int language plpgsql security definer set search_path = public as $$
declare v_n int;
begin
  with g as (
    select distinct giocatore_id as id from public.posizioni where partita_id = p_partita and giocatore_id is not null
  ), coppie as (
    select a.id as x, b.id as y from g a join g b on a.id < b.id
  )
  insert into public.amicizie (da_id, a_id, stato, risposto_il)
  select x, y, 'accettata', now() from coppie
  on conflict (least(da_id, a_id), greatest(da_id, a_id)) do update set stato = 'accettata', risposto_il = now()
    where public.amicizie.stato <> 'accettata';
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke execute on function public.amici_dalla_partita(uuid) from public, anon, authenticated;

create or replace function public.aggiorna_stati_partite()
returns void language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  for v_id in
    update public.partite set stato = 'giocata'
    where stato in ('aperta', 'completa') and data_ora <= now() - interval '1 hour'
    returning id
  loop
    perform public.amici_dalla_partita(v_id);
  end loop;

  update public.partite set archiviata = true, archiviata_il = now()
  where not archiviata and stato in ('giocata', 'annullata')
    and (data_ora at time zone 'Europe/Rome')::date < (now() at time zone 'Europe/Rome')::date;
end $$;

-- le partite già giocate: amici anche per il passato
do $$
declare v_id uuid;
begin
  for v_id in select id from public.partite where stato = 'giocata' loop
    perform public.amici_dalla_partita(v_id);
  end loop;
end $$;

-- notifica solo quando qualcuno ti aggiunge a mano (non per gli amici automatici)
create or replace function public.push_amicizie()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.stato = 'accettata' and auth.uid() is not null and new.da_id = auth.uid()
       and (tg_op = 'INSERT' or old.stato is distinct from 'accettata') then
      perform public.invia_push(array[new.a_id], 'Nuovo amico',
        public.nome_breve(new.da_id) || ' ti ha aggiunto agli amici su Ne manca 1', '/amici');
    end if;
  exception when others then raise warning 'push_amicizie: %', sqlerrm;
  end;
  return new;
end $$;

-- ---------------------------------------------------------------------
-- Liste di giocatori (private: le vede solo chi le crea)
-- ---------------------------------------------------------------------
create table if not exists public.liste (
  id uuid primary key default gen_random_uuid(),
  proprietario_id uuid not null references public.profili(id) on delete cascade,
  nome text not null check (char_length(btrim(nome)) between 1 and 40),
  creato_il timestamptz not null default now()
);
create table if not exists public.liste_membri (
  lista_id uuid not null references public.liste(id) on delete cascade,
  giocatore_id uuid not null references public.profili(id) on delete cascade,
  aggiunto_il timestamptz not null default now(),
  primary key (lista_id, giocatore_id)
);
alter table public.liste enable row level security;
alter table public.liste_membri enable row level security;
drop policy if exists "liste mie" on public.liste;
create policy "liste mie" on public.liste for select to authenticated using (proprietario_id = auth.uid());
drop policy if exists "membri delle mie liste" on public.liste_membri;
create policy "membri delle mie liste" on public.liste_membri for select to authenticated
  using (exists (select 1 from public.liste l where l.id = lista_id and l.proprietario_id = auth.uid()));

create or replace function public.crea_lista(p_nome text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Devi essere autenticato'; end if;
  if char_length(btrim(coalesce(p_nome, ''))) = 0 then raise exception 'Scrivi un nome per la lista'; end if;
  insert into public.liste (proprietario_id, nome) values (auth.uid(), left(btrim(p_nome), 40)) returning id into v_id;
  return v_id;
end $$;

create or replace function public.rinomina_lista(p_lista uuid, p_nome text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if char_length(btrim(coalesce(p_nome, ''))) = 0 then raise exception 'Scrivi un nome per la lista'; end if;
  update public.liste set nome = left(btrim(p_nome), 40) where id = p_lista and proprietario_id = auth.uid();
  if not found then raise exception 'Lista non trovata'; end if;
end $$;

create or replace function public.elimina_lista(p_lista uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.liste where id = p_lista and proprietario_id = auth.uid();
$$;

-- aggiungere a una lista rende anche amici (senza conferma)
create or replace function public.aggiungi_a_lista(p_lista uuid, p_giocatore uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.liste where id = p_lista and proprietario_id = auth.uid()) then raise exception 'Lista non trovata'; end if;
  if p_giocatore = auth.uid() then raise exception 'Non serve aggiungere te stesso'; end if;
  if not public.sono_amici(auth.uid(), p_giocatore) then perform public.chiedi_amicizia(p_giocatore); end if;
  insert into public.liste_membri (lista_id, giocatore_id) values (p_lista, p_giocatore) on conflict do nothing;
end $$;

create or replace function public.togli_da_lista(p_lista uuid, p_giocatore uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.liste_membri m using public.liste l
  where m.lista_id = l.id and l.id = p_lista and l.proprietario_id = auth.uid() and m.giocatore_id = p_giocatore;
$$;

-- le mie liste con i membri (nome, iniziali, foto)
create or replace function public.mie_liste()
returns table (id uuid, nome text, membri jsonb)
language sql stable security definer set search_path = public as $$
  select l.id, l.nome,
         coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'nome', p.nome, 'iniziali', p.iniziali, 'foto_url', p.foto_url) order by p.nome)
                   from public.liste_membri m join public.profili p on p.id = m.giocatore_id where m.lista_id = l.id), '[]'::jsonb)
  from public.liste l
  where l.proprietario_id = auth.uid()
  order by l.creato_il;
$$;

grant execute on function public.crea_lista(text), public.rinomina_lista(uuid, text), public.elimina_lista(uuid),
  public.aggiungi_a_lista(uuid, uuid), public.togli_da_lista(uuid, uuid), public.mie_liste() to authenticated;

-- ---------------------------------------------------------------------
-- Email (Resend). Chiave nel Vault con nome 'resend_api_key': senza chiave non parte nulla.
-- ---------------------------------------------------------------------
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
        'from', 'Ne manca 1 <benvenuto@nemanca1.com>',
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

create or replace function public.testo_html(p text)
returns text language sql immutable as $$
  select replace(replace(replace(replace(coalesce(p, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;');
$$;

-- invito a una partita: notifica + email con il link diretto alla partita
create or replace function public.push_inviti()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_da text; v_desc text; v_link text;
begin
  begin
    if new.stato = 'in_attesa' and (tg_op = 'INSERT' or old.stato is distinct from 'in_attesa') then
      v_da := public.nome_breve(new.da_id);
      v_desc := public.descrivi_partita(new.partita_id);
      v_link := 'https://www.nemanca1.com/partita/' || new.partita_id;
      perform public.invia_push(array[new.a_id], 'Ti invitano a giocare', v_da || ' ti invita · ' || v_desc, '/partita/' || new.partita_id);
      perform public.invia_email(new.a_id,
        v_da || ' ti invita a giocare · ' || v_desc,
        '<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;color:#14201A">'
          || '<h2 style="color:#1E7B4E;margin:0 0 12px">Ne manca 1</h2>'
          || '<p style="font-size:16px"><strong>' || public.testo_html(v_da) || '</strong> ti invita a giocare:</p>'
          || '<p style="font-size:16px;background:#F2F5F1;border-radius:12px;padding:12px 14px">' || public.testo_html(v_desc) || '</p>'
          || '<p><a href="' || v_link || '" style="display:inline-block;background:#1E7B4E;color:#fff;text-decoration:none;font-weight:bold;padding:14px 22px;border-radius:12px">Apri la partita</a></p>'
          || '<p style="font-size:13px;color:#5B6B62">Dalla partita puoi accettare l''invito o restare in tribuna. Se il bottone non funziona copia questo indirizzo: ' || v_link || '</p>'
          || '</div>',
        v_da || ' ti invita a giocare: ' || v_desc || E'\nApri la partita: ' || v_link);
    end if;
  exception when others then raise warning 'push_inviti: %', sqlerrm;
  end;
  return new;
end $$;
