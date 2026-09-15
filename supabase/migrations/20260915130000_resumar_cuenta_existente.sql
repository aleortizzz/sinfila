-- ============================================================
-- Bug real: "Quitar" del equipo solo borra la fila de usuario_local_roles
-- (a propósito, para no perder la cuenta si se la vuelve a sumar después)
-- pero la cuenta de auth sigue existiendo. Al intentar "Sumar a alguien"
-- con ese mismo mail, auth.signUp() la rechaza ("ya existe una cuenta") y
-- ahí se cortaba todo — no había forma de volver a sumarla sin poder
-- borrar la cuenta de auth a mano.
--
-- Esta función busca una cuenta de auth existente por mail y, si no tiene
-- ya un rol en ESTE local, le asigna uno directo — sin pasar por
-- auth.signUp() de nuevo. El frontend la usa como fallback cuando
-- signUp() avisa que el mail ya está registrado.
-- ============================================================

create or replace function sumar_usuario_existente(
  p_local_id uuid,
  p_email text,
  p_rol text,
  p_ve_facturacion boolean,
  p_edita_menu boolean,
  p_nombre text default null,
  p_telefono text default null
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_usuario_id uuid;
begin
  if not es_dueño_local(p_local_id) then
    raise exception 'No tenés permiso para gestionar el equipo de este local.';
  end if;

  select id into v_usuario_id from auth.users where lower(email) = lower(trim(p_email));
  if not found then
    raise exception 'No encontramos ninguna cuenta con ese mail.';
  end if;

  if exists (select 1 from usuario_local_roles where usuario_id = v_usuario_id and local_id = p_local_id) then
    raise exception 'Esa persona ya es parte de este equipo.';
  end if;

  insert into usuario_local_roles (usuario_id, local_id, rol, ve_facturacion, edita_menu, nombre, telefono)
  values (v_usuario_id, p_local_id, p_rol, p_ve_facturacion, p_edita_menu, p_nombre, p_telefono);

  return v_usuario_id;
end;
$$;

grant execute on function sumar_usuario_existente(uuid, text, text, boolean, boolean, text, text) to authenticated;
