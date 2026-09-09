-- ============================================================
-- Estadísticas del Inicio del panel (solo el dueño; el discovery dejó
-- "estadísticas/reportes" como algo del dueño, no del staff).
-- Todo en hora de Argentina. Excluye pedidos rechazados/cancelados.
-- ============================================================

create or replace function estadisticas_local(p_local_id uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  with lim as (
    select
      hoy_ar() as hoy,
      (hoy_ar() - 6) as hace_7,                       -- 7 días incluyendo hoy
      date_trunc('month', hoy_ar())::date as inicio_mes
  ),
  p as (
    select
      pe.total,
      (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date as fecha
    from pedidos pe, lim
    where pe.local_id = p_local_id
      and pe.estado not in ('rechazado', 'cancelado')
      and (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date >= lim.inicio_mes
  )
  select jsonb_build_object(
    'pedidos_hoy',       (select count(*) from p, lim where p.fecha = lim.hoy),
    'ventas_hoy',        (select coalesce(sum(total), 0) from p, lim where p.fecha = lim.hoy),
    'pedidos_7d',        (select count(*) from p, lim where p.fecha >= lim.hace_7),
    'ventas_7d',         (select coalesce(sum(total), 0) from p, lim where p.fecha >= lim.hace_7),
    'ventas_mes',        (select coalesce(sum(total), 0) from p),
    'productos_activos', (select count(*) from productos where local_id = p_local_id and disponible)
  )
  where es_dueño_local(p_local_id);
$$;

grant execute on function estadisticas_local(uuid) to authenticated;
