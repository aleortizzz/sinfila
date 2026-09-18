-- ============================================================
-- Formulario de SEO para JC Barandas (jcbarandas.com.ar) — un cliente
-- externo sin base propia (sitio estático). Se aprovecha esta base
-- porque ya está armada, pero es un feature completamente aislado del
-- resto de SinFila:
--   - Tabla propia, sin relación con locales/negocios/usuarios.
--   - No hay ninguna pantalla del admin que la lea ni la liste.
--   - Solo INSERT público (sin auth) para que el cliente complete el
--     form sin cuenta; nadie puede LEER las respuestas vía API (ni
--     anon ni authenticated) — se consultan directo desde el Table
--     Editor de Supabase con el rol postgres, que no pasa por RLS.
-- ============================================================

create table jcbarandas_seo_respuestas (
  id uuid primary key default gen_random_uuid(),
  respuestas jsonb not null,
  creado_en timestamptz not null default now()
);

alter table jcbarandas_seo_respuestas enable row level security;

create policy jcbarandas_seo_insert on jcbarandas_seo_respuestas
  for insert to anon, authenticated
  with check (true);

-- Sin policy de select/update/delete a propósito: nadie puede leer ni
-- tocar respuestas ajenas vía la API pública.
