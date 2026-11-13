-- 0022: foto del giocatore. Il telefono la riduce (quadrata, pochi KB) prima di caricarla
-- nello spazio "foto" di Supabase Storage; nel profilo resta l'indirizzo. Rieseguibile.
alter table public.profili add column if not exists foto_url text;

-- su Supabase esiste lo schema storage; sul Postgres di prova si salta
do $$
begin
  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('foto', 'foto', true, 307200, array['image/webp', 'image/jpeg'])
  on conflict (id) do update set public = true, file_size_limit = 307200, allowed_mime_types = array['image/webp', 'image/jpeg'];

  drop policy if exists "foto: carico le mie" on storage.objects;
  create policy "foto: carico le mie" on storage.objects for insert to authenticated
    with check (bucket_id = 'foto' and (storage.foldername(name))[1] = auth.uid()::text);
  drop policy if exists "foto: cambio le mie" on storage.objects;
  create policy "foto: cambio le mie" on storage.objects for update to authenticated
    using (bucket_id = 'foto' and (storage.foldername(name))[1] = auth.uid()::text);
  drop policy if exists "foto: tolgo le mie" on storage.objects;
  create policy "foto: tolgo le mie" on storage.objects for delete to authenticated
    using (bucket_id = 'foto' and (storage.foldername(name))[1] = auth.uid()::text);
exception when undefined_table or invalid_schema_name or undefined_function then
  raise notice 'storage non disponibile: %', sqlerrm;
end $$;
