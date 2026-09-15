-- ============================================================
-- Ficha de empleado: nombre, teléfono y notas por persona del equipo.
-- El teléfono ya se pedía al crear la cuenta (para el link de WhatsApp)
-- pero se perdía después — ahora se guarda.
-- ============================================================

alter table usuario_local_roles
  add column nombre text,
  add column telefono text,
  add column notas text;

drop function if exists listar_equipo_local(uuid);

create function listar_equipo_local(p_local_id uuid)
returns table (
  usuario_id uuid,
  email text,
  rol text,
  ve_facturacion boolean,
  edita_menu boolean,
  creado timestamptz,
  email_confirmado boolean,
  ultimo_acceso timestamptz,
  nombre text,
  telefono text,
  notas text
)
language sql stable security definer set search_path = public as $$
  select
    ulr.usuario_id, u.email, ulr.rol, ulr.ve_facturacion, ulr.edita_menu, ulr.created_at,
    u.email_confirmed_at is not null, u.last_sign_in_at,
    ulr.nombre, ulr.telefono, ulr.notas
  from usuario_local_roles ulr
  join auth.users u on u.id = ulr.usuario_id
  where ulr.local_id = p_local_id and es_dueño_local(p_local_id)
  order by (ulr.rol = 'dueño') desc, ulr.created_at;
$$;

grant execute on function listar_equipo_local(uuid) to authenticated;

-- El propio dueño/administrador ya puede escribir estas columnas (mismo
-- UPDATE de siempre sobre usuario_local_roles, dueño-only) — no hace
-- falta ninguna función nueva para editar la ficha.
