-- ============================================================
-- SinFila — Hito 2c: suscripciones (activar local, registrar pagos,
-- suspensión automática por falta de pago)
-- ============================================================

-- "Hoy" según la zona horaria fija del negocio, no la del servidor (UTC).
create or replace function hoy_ar()
returns date
language sql stable as $$
  select (now() at time zone 'America/Argentina/Buenos_Aires')::date;
$$;

-- ============================================================
-- 1) Columnas de suscripción que faltaban en locales
-- ============================================================

alter table locales add column precio_mensual numeric(10,2) not null default 0;
alter table locales add column proximo_vencimiento date;
-- Se completa al entrar en gracia (vencimiento + 5 días); se limpia al pagar.
alter table locales add column gracia_hasta date;

-- ============================================================
-- 2) Historial de pagos
-- ============================================================

create table pagos_suscripcion (
  id uuid primary key default gen_random_uuid(),
  local_id uuid references locales(id) on delete cascade not null,
  monto numeric(10,2) not null,
  metodo text not null default 'transferencia',
  -- Período que cubre este pago (siempre 1 mes en el MVP).
  periodo_desde date not null,
  periodo_hasta date not null,
  registrado_por uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index pagos_suscripcion_local_id_idx on pagos_suscripcion(local_id);

alter table pagos_suscripcion enable row level security;

create policy pagos_suscripcion_select on pagos_suscripcion for select
  using (es_dueño_local(local_id));
-- Sin insert/update/delete: solo se cargan a través de registrar_pago().

-- ============================================================
-- 3) Funciones (llamadas por el super-admin desde el futuro panel)
-- ============================================================

-- El dueño se registró y quedó "pendiente_activacion"; el super-admin lo
-- activa, define su precio mensual, y arrancan los 30 días de prueba.
create or replace function activar_local(p_local_id uuid, p_precio_mensual numeric)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not es_super_admin() then
    raise exception 'Solo el super-admin puede activar un local';
  end if;

  update locales
    set estado = 'trial',
        trial_hasta = hoy_ar() + 30,
        precio_mensual = p_precio_mensual
    where id = p_local_id and estado = 'pendiente_activacion';

  if not found then
    raise exception 'El local no existe o no está pendiente de activación';
  end if;
end;
$$;

-- El super-admin marca que un local pagó. Extiende el vencimiento un mes
-- desde el vencimiento anterior (si todavía no venció) o desde hoy (si ya
-- estaba vencido/en gracia/suspendido), y reactiva el local.
create or replace function registrar_pago(p_local_id uuid, p_monto numeric, p_metodo text default 'transferencia')
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_desde date;
  v_hasta date;
begin
  if not es_super_admin() then
    raise exception 'Solo el super-admin puede registrar pagos';
  end if;

  select case when proximo_vencimiento is null or proximo_vencimiento < hoy_ar()
           then hoy_ar() else proximo_vencimiento end
    into v_desde
    from locales where id = p_local_id;

  if not found then
    raise exception 'Local no encontrado';
  end if;

  v_hasta := (v_desde + interval '1 month')::date;

  insert into pagos_suscripcion (local_id, monto, metodo, periodo_desde, periodo_hasta, registrado_por)
  values (p_local_id, p_monto, p_metodo, v_desde, v_hasta, auth.uid());

  update locales
    set estado = 'activo',
        proximo_vencimiento = v_hasta,
        gracia_hasta = null
    where id = p_local_id;
end;
$$;

-- Corre una vez por día (ver el cron job más abajo). Puramente basada en
-- fechas: no manda avisos ni nada — eso (el "se corta en 3 días") es
-- trabajo del panel/notificaciones del Hito 8, esto solo mueve el estado.
create or replace function actualizar_estados_vencidos()
returns void
language plpgsql security definer set search_path = public as $$
begin
  -- se venció el trial sin pagar -> entra en gracia (5 días)
  update locales set estado = 'gracia', gracia_hasta = trial_hasta + 5
    where estado = 'trial' and trial_hasta < hoy_ar();

  -- se venció la suscripción paga -> entra en gracia (5 días)
  update locales set estado = 'gracia', gracia_hasta = proximo_vencimiento + 5
    where estado = 'activo' and proximo_vencimiento < hoy_ar();

  -- se venció la gracia sin pagar -> suspendido (carta offline)
  update locales set estado = 'suspendido'
    where estado = 'gracia' and gracia_hasta < hoy_ar();
end;
$$;

-- Solo el super-admin (autenticado) puede invocar activar/registrar pago;
-- el chequeo real está adentro de la función, esto es defensa en profundidad.
revoke execute on function activar_local(uuid, numeric) from public;
grant execute on function activar_local(uuid, numeric) to authenticated;

revoke execute on function registrar_pago(uuid, numeric, text) from public;
grant execute on function registrar_pago(uuid, numeric, text) to authenticated;

-- Esta la corre únicamente el cron interno: nadie la llama por API.
revoke execute on function actualizar_estados_vencidos() from public, anon, authenticated;

-- ============================================================
-- 4) Cron: corre todos los días a las 03:00 hora Argentina (06:00 UTC)
-- ============================================================

create extension if not exists pg_cron;

select cron.schedule(
  'actualizar-estados-locales',
  '0 6 * * *',
  $$select actualizar_estados_vencidos()$$
);
