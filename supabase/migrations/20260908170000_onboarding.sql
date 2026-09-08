-- ============================================================
-- Onboarding autogestionable + soporte para el panel de super-admin.
--
-- Antes: el alta de un local se hacía a mano por SQL (RLS reserva el INSERT
-- en locales al super-admin). Ahora un dueño se registra solo: crea su
-- cuenta de auth y llama a registrar_negocio(), que arma negocio + local
-- (pendiente_activacion) + rol de dueño. El super-admin lo activa después.
-- ============================================================

create or replace function registrar_negocio(
  p_nombre_negocio text,
  p_nombre_local text,
  p_slug text
)
returns text
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_negocio_id uuid;
  v_local_id uuid;
begin
  if v_uid is null then
    raise exception 'Tenés que iniciar sesión';
  end if;
  if coalesce(trim(p_nombre_negocio), '') = '' or coalesce(trim(p_nombre_local), '') = '' then
    raise exception 'Faltan el nombre del negocio o del local';
  end if;
  if p_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    raise exception 'La URL solo puede tener minúsculas, números y guiones';
  end if;
  if exists (select 1 from locales where slug = p_slug) then
    raise exception 'Esa URL ya está en uso, probá con otra';
  end if;
  -- MVP: un usuario = un local.
  if exists (select 1 from usuario_local_roles where usuario_id = v_uid) then
    raise exception 'Esta cuenta ya tiene un local registrado';
  end if;

  insert into negocios (nombre, email_contacto)
  values (trim(p_nombre_negocio), (select email from auth.users where id = v_uid))
  returning id into v_negocio_id;

  insert into locales (negocio_id, nombre, slug, estado)
  values (v_negocio_id, trim(p_nombre_local), p_slug, 'pendiente_activacion')
  returning id into v_local_id;

  insert into usuario_local_roles (usuario_id, local_id, rol)
  values (v_uid, v_local_id, 'dueño');

  -- 7 días de horario, abierto todo el día por defecto.
  insert into horarios_local (local_id, dia, abierto)
  select v_local_id, g, true from generate_series(0, 6) g;

  return p_slug;
end;
$$;

grant execute on function registrar_negocio(text, text, text) to authenticated;

-- El panel de super-admin necesita ver TODOS los locales (incluidos los
-- pendientes y los suspendidos) con datos del negocio. security definer +
-- chequeo interno.
create or replace function listar_locales_superadmin()
returns table (
  local_id uuid,
  local_nombre text,
  slug text,
  estado text,
  negocio_nombre text,
  email_contacto text,
  precio_mensual numeric,
  trial_hasta date,
  proximo_vencimiento date,
  gracia_hasta date,
  creado timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    l.id, l.nombre, l.slug, l.estado,
    n.nombre, n.email_contacto,
    l.precio_mensual, l.trial_hasta, l.proximo_vencimiento, l.gracia_hasta,
    l.created_at
  from locales l
  join negocios n on n.id = l.negocio_id
  where es_super_admin()
  order by l.created_at desc;
$$;

grant execute on function listar_locales_superadmin() to authenticated;

-- Para que el front sepa si mostrar el link/ruta del panel de super-admin.
grant execute on function es_super_admin() to authenticated;
