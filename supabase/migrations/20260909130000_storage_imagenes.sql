-- ============================================================
-- Bucket público para logo / banner / fotos de producto. Antes se pegaba
-- una URL a mano; ahora se sube el archivo.
--
-- Convención de path:  <carpeta>/<local_id>/<archivo>
--   locales/<local_id>/logo-<ts>.png
--   locales/<local_id>/banner-<ts>.jpg
--   productos/<local_id>/<producto_id>-<ts>.webp
-- El 2º segmento es siempre el local_id → la escritura la habilita
-- es_dueño_local() sobre ese id.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'imagenes', 'imagenes', true, 5242880,
  array['image/png', 'image/jpeg', 'image/webp', 'image/gif']
)
on conflict (id) do nothing;

-- Lectura: el bucket es público (la carta muestra las imágenes sin login).
create policy "imagenes lectura publica"
  on storage.objects for select
  using (bucket_id = 'imagenes');

-- Escritura / reemplazo / borrado: solo el dueño (o super-admin) del local
-- cuyo id es el 2º segmento del path.
create policy "imagenes escribe el dueno"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'imagenes'
    and public."es_dueño_local"(((storage.foldername(name))[2])::uuid)
  );

create policy "imagenes actualiza el dueno"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'imagenes'
    and public."es_dueño_local"(((storage.foldername(name))[2])::uuid)
  );

create policy "imagenes borra el dueno"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'imagenes'
    and public."es_dueño_local"(((storage.foldername(name))[2])::uuid)
  );
