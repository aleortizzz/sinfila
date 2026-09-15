-- ============================================================
-- Hito: "Equipo" — el dueño da de alta cuentas de staff sin tocar SQL.
--
-- El alta en sí (crear la cuenta de auth) la hace el cliente con
-- auth.signUp() sobre un cliente Supabase aparte (sin persistir sesión),
-- así no le pisa la sesión al dueño logueado. Acá solo agregamos la
-- función para LISTAR el equipo con el email — auth.users no es una tabla
-- expuesta por PostgREST, hace falta security definer para leerla.
-- ============================================================

create or replace function listar_equipo_local(p_local_id uuid)
returns table (usuario_id uuid, email text, rol text, creado timestamptz)
language sql stable security definer set search_path = public as $$
  select ulr.usuario_id, u.email, ulr.rol, ulr.created_at
  from usuario_local_roles ulr
  join auth.users u on u.id = ulr.usuario_id
  where ulr.local_id = p_local_id and es_dueño_local(p_local_id)
  order by (ulr.rol = 'dueño') desc, ulr.created_at;
$$;

grant execute on function listar_equipo_local(uuid) to authenticated;
