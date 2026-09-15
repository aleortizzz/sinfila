-- ============================================================
-- Forzar cambio de contraseña en el primer login para cuentas de staff
-- creadas por el dueño con una contraseña generada — para que no se quede
-- con esa contraseña rara para siempre.
-- ============================================================

alter table usuario_local_roles
  add column debe_cambiar_password boolean not null default false;

-- El propio usuario puede marcar que ya la cambió (sin darle permiso de
-- UPDATE directo sobre la tabla, que sigue siendo dueño-only) — acotado a
-- auth.uid(), no puede tocar la fila de nadie más.
create or replace function marcar_password_cambiada()
returns void
language sql security definer set search_path = public as $$
  update usuario_local_roles set debe_cambiar_password = false where usuario_id = auth.uid();
$$;

grant execute on function marcar_password_cambiada() to authenticated;
