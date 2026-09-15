-- ============================================================
-- Revierte el rate-limit global de 20260911100000.
--
-- Contar "cuántos locales se crearon en total en la última hora" castiga
-- el volumen, no el abuso: un pico real de altas (varios dueños genuinos
-- registrándose la misma hora) se bloquearía igual que un bot. La señal
-- correcta para frenar spam es "muchos intentos desde el MISMO origen", y
-- eso no se puede ver de forma confiable acá adentro (Postgres no conoce
-- la IP del caller, solo al usuario ya autenticado).
--
-- La barrera real contra creación masiva de cuentas ya la pone Supabase
-- Auth (rate-limit de signup por IP, antes de que se pueda llamar a esta
-- función). Si en el futuro hace falta más, el fix es un captcha
-- (Turnstile/hCaptcha) en /registro — discrimina bot vs. humano sin
-- penalizar el volumen de altas reales.
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
