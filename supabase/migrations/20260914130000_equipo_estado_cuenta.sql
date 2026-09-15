-- ============================================================
-- Equipo: sumar estado de la cuenta al listado — para 3 mejoras a la
-- pantalla (2026-09-14): badge "mail sin confirmar", "última vez que
-- entró", y un botón de "restablecer contraseña" (este último no necesita
-- cambios en la base, reusa auth.resetPasswordForEmail del lado del
-- cliente).
-- ============================================================

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
  ultimo_acceso timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    ulr.usuario_id, u.email, ulr.rol, ulr.ve_facturacion, ulr.edita_menu, ulr.created_at,
    u.email_confirmed_at is not null, u.last_sign_in_at
  from usuario_local_roles ulr
  join auth.users u on u.id = ulr.usuario_id
  where ulr.local_id = p_local_id and es_dueño_local(p_local_id)
  order by (ulr.rol = 'dueño') desc, ulr.created_at;
$$;

grant execute on function listar_equipo_local(uuid) to authenticated;
