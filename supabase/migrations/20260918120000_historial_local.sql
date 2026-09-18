-- ============================================================
-- Historial de movimientos por local, para el super-admin: pagos (con
-- % de aumento vs el pago anterior si hubo), y eventos de suscripción
-- (activación, entrada en gracia, suspensión —manual o automática—,
-- carta habilitada/deshabilitada). Antes no quedaba ningún rastro de
-- estos cambios de estado: la fila de `locales` solo guarda el estado
-- ACTUAL, no cómo se llegó ahí.
-- ============================================================

create table locales_eventos (
  id uuid primary key default gen_random_uuid(),
  local_id uuid references locales(id) on delete cascade not null,
  tipo text not null check (tipo in ('activacion', 'gracia', 'suspension', 'carta_deshabilitada', 'carta_habilitada')),
  detalle text,
  creado_en timestamptz not null default now()
);

create index locales_eventos_local_id_idx on locales_eventos(local_id);

-- Sin policies a propósito (RLS habilitado = deny-all por default): esta
-- tabla nunca se consulta directo desde el front, solo a través de
-- historial_local() más abajo, que es security definer y ya valida
-- es_super_admin() por su cuenta.
alter table locales_eventos enable row level security;

-- --- Registrar el evento en cada punto donde ya cambiaba el estado ---

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

  insert into locales_eventos (local_id, tipo, detalle)
    values (p_local_id, 'activacion', format('Local activado — prueba de 30 días, $%s/mes', p_precio_mensual));
end;
$$;

create or replace function suspender_local(p_local_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not es_super_admin() then
    raise exception 'Solo el super-admin puede suspender un local';
  end if;
  update locales set estado = 'suspendido' where id = p_local_id;
  if not found then
    raise exception 'Local no encontrado';
  end if;

  insert into locales_eventos (local_id, tipo, detalle)
    values (p_local_id, 'suspension', 'Suspendido a mano desde SuperAdmin');
end;
$$;

-- El cron: acá pasan las transiciones AUTOMÁTICAS por falta de pago —
-- las más importantes de dejar registradas, porque nadie las dispara a
-- mano.
create or replace function actualizar_estados_vencidos()
returns void
language plpgsql security definer set search_path = public as $$
begin
  -- se venció el trial sin pagar -> entra en gracia (5 días)
  insert into locales_eventos (local_id, tipo, detalle)
    select id, 'gracia', 'Venció el período de prueba sin pagar'
    from locales where estado = 'trial' and trial_hasta < hoy_ar();
  update locales set estado = 'gracia', gracia_hasta = trial_hasta + 5
    where estado = 'trial' and trial_hasta < hoy_ar();

  -- se venció la suscripción paga -> entra en gracia (5 días)
  insert into locales_eventos (local_id, tipo, detalle)
    select id, 'gracia', 'Venció la suscripción sin renovarse'
    from locales where estado = 'activo' and proximo_vencimiento < hoy_ar();
  update locales set estado = 'gracia', gracia_hasta = proximo_vencimiento + 5
    where estado = 'activo' and proximo_vencimiento < hoy_ar();

  -- se venció la gracia sin pagar -> suspendido (carta offline)
  insert into locales_eventos (local_id, tipo, detalle)
    select id, 'suspension', 'Automático — venció el período de gracia sin pagar'
    from locales where estado = 'gracia' and gracia_hasta < hoy_ar();
  update locales set estado = 'suspendido'
    where estado = 'gracia' and gracia_hasta < hoy_ar();
end;
$$;

create or replace function alternar_carta_local(p_local_id uuid, p_deshabilitada boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not es_super_admin() then
    raise exception 'Solo el super-admin puede hacer esto.';
  end if;
  update locales set carta_deshabilitada = p_deshabilitada where id = p_local_id;
  if not found then
    raise exception 'Local no encontrado';
  end if;

  insert into locales_eventos (local_id, tipo, detalle)
    values (
      p_local_id,
      case when p_deshabilitada then 'carta_deshabilitada' else 'carta_habilitada' end,
      case when p_deshabilitada then 'Carta bajada desde SuperAdmin' else 'Carta vuelta a habilitar desde SuperAdmin' end
    );
end;
$$;

-- --- Historial combinado: pagos (con % de aumento) + eventos ---

create or replace function historial_local(p_local_id uuid)
returns table (
  fecha timestamptz,
  tipo text,
  detalle text,
  monto numeric,
  variacion_pct numeric
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not es_super_admin() then
    raise exception 'Solo el super-admin puede ver el historial.';
  end if;

  return query
  with pagos as (
    select
      created_at as fecha,
      'pago'::text as tipo,
      format('Pago de $%s (período %s a %s, %s)', monto, periodo_desde, periodo_hasta, metodo) as detalle,
      monto,
      case
        when lag(monto) over (order by created_at) > 0
             and monto > lag(monto) over (order by created_at)
        then round((monto - lag(monto) over (order by created_at)) / lag(monto) over (order by created_at) * 100, 1)
        else null
      end as variacion_pct
    from pagos_suscripcion
    where local_id = p_local_id
  ),
  eventos as (
    select creado_en as fecha, tipo, detalle, null::numeric as monto, null::numeric as variacion_pct
    from locales_eventos
    where local_id = p_local_id
  )
  select * from pagos
  union all
  select * from eventos
  order by fecha desc;
end;
$$;

revoke execute on function historial_local(uuid) from public;
grant execute on function historial_local(uuid) to authenticated;
