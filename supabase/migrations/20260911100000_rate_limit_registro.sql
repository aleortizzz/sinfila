-- ============================================================
-- Rate-limit de registrar_negocio (pendiente anotado en el Hito 8).
--
-- registrar_negocio() ya bloquea que UN MISMO usuario cree más de un local
-- ("Esta cuenta ya tiene un local registrado"). El hueco real es un script
-- que crea muchas cuentas de auth nuevas y llama la función una vez por
-- cuenta, llenando `locales`/`negocios` de altas basura en
-- `pendiente_activacion`. No tenemos la IP del caller disponible de forma
-- confiable dentro de la función, así que el tope es GLOBAL por ventana de
-- tiempo: si ya se crearon demasiados locales en la última hora (sea cual
-- sea la cuenta), se corta. No afecta el uso real (altas genuinas son
-- esporádicas en esta etapa), pero acota el daño de cualquier ráfaga.
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
  -- Rate-limit global: corta ráfagas de altas (spam de cuentas nuevas).
  if (select count(*) from locales where created_at > now() - interval '1 hour') >= 10 then
    raise exception 'Estamos recibiendo muchas altas en este momento. Probá de nuevo en un rato.';
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
