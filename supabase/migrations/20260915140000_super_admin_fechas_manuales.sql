-- ============================================================
-- Herramienta de testing para el super-admin: poder mover a mano las
-- fechas de suscripción de un local (trial_hasta/proximo_vencimiento/
-- gracia_hasta) y forzar el chequeo diario de vencimientos sin esperar
-- al cron ni tocar la base directo por SQL. Pedido del usuario para
-- poder "jugar" con el banner de gracia (2026-09-15) sin depender de
-- que pase un mes real.
--
-- El dueño del local sigue sin poder tocar estas columnas (protegidas
-- por GRANT desde 20260907120000_base_multi_local_menu.sql) — esto es
-- exclusivamente para el super-admin, mismo guard que activar_local()/
-- registrar_pago().
-- ============================================================

create or replace function fijar_fechas_local(
  p_local_id uuid,
  p_trial_hasta date,
  p_proximo_vencimiento date,
  p_gracia_hasta date
)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not es_super_admin() then
    raise exception 'Solo el super-admin puede tocar las fechas de suscripción.';
  end if;

  update locales
    set trial_hasta = p_trial_hasta,
        proximo_vencimiento = p_proximo_vencimiento,
        gracia_hasta = p_gracia_hasta
    where id = p_local_id;

  if not found then
    raise exception 'Local no encontrado';
  end if;
end;
$$;

revoke execute on function fijar_fechas_local(uuid, date, date, date) from public;
grant execute on function fijar_fechas_local(uuid, date, date, date) to authenticated;

-- actualizar_estados_vencidos() sigue sin ser invocable directo (solo el
-- cron interno) — este wrapper la corre bajo el mismo guard de
-- es_super_admin(), para poder ver el efecto de las fechas de arriba al
-- toque en vez de esperar a que corra a la madrugada.
create or replace function actualizar_estados_vencidos_ahora()
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not es_super_admin() then
    raise exception 'Solo el super-admin puede forzar el chequeo de vencimientos.';
  end if;
  perform actualizar_estados_vencidos();
end;
$$;

revoke execute on function actualizar_estados_vencidos_ahora() from public;
grant execute on function actualizar_estados_vencidos_ahora() to authenticated;
