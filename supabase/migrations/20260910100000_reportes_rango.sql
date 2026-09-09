-- ============================================================
-- reporte_local e historial_pedidos pasan a tomar un rango de fechas
-- explícito (p_desde / p_hasta), calculado en el front (lib/periodos.js).
-- Antes tomaban "p_dias" (7/30/90). Ahora se puede filtrar por mes, etc.
-- p_desde null = desde que se creó el local. reporte_local recibe además
-- el rango del período anterior para la comparación.
-- ============================================================

drop function if exists reporte_local(uuid, int);
drop function if exists historial_pedidos(uuid, int, text, int, int);

create or replace function reporte_local(
  p_local_id uuid,
  p_desde date default null,
  p_hasta date default null,
  p_prev_desde date default null,
  p_prev_hasta date default null
)
returns jsonb
language sql stable security definer set search_path = public as $$
  with cfg as (
    select
      coalesce(
        p_desde,
        (select (l.created_at at time zone 'America/Argentina/Buenos_Aires')::date from locales l where l.id = p_local_id)
      ) as desde,
      coalesce(p_hasta, hoy_ar()) as hasta
  ),
  ped as (
    select
      pe.id, pe.total,
      (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date as fecha
    from pedidos pe, cfg
    where pe.local_id = p_local_id
      and pe.estado not in ('rechazado', 'cancelado')
      and pe.created_at >= (coalesce(p_prev_desde, (select desde from cfg))::timestamptz - interval '2 days')
  ),
  base as (select p.* from ped p, cfg where p.fecha between cfg.desde and cfg.hasta),
  base_prev as (
    select p.* from ped p
    where p_prev_desde is not null and p.fecha between p_prev_desde and p_prev_hasta
  ),
  dias as (select d::date as fecha from cfg, generate_series(cfg.desde, cfg.hasta, interval '1 day') d),
  serie as (
    select dias.fecha, count(b.id) as pedidos, coalesce(sum(b.total), 0)::numeric as ventas
    from dias left join base b on b.fecha = dias.fecha
    group by dias.fecha
  ),
  top as (
    select
      pi.nombre,
      sum(pi.cantidad)::int as unidades,
      sum((pi.precio_unitario - coalesce(pi.descuento_aplicado, 0)) * pi.cantidad)::numeric as monto
    from pedido_items pi join base b on b.id = pi.pedido_id
    group by pi.nombre order by unidades desc limit 10
  ),
  resumen as (
    select 'r' as k, count(*) as pedidos, coalesce(sum(total), 0)::numeric as ventas,
      case when count(*) > 0 then round(sum(total) / count(*)) else 0 end as ticket
    from base
    union all
    select 'p', count(*), coalesce(sum(total), 0)::numeric,
      case when count(*) > 0 then round(sum(total) / count(*)) else 0 end
    from base_prev
  )
  select jsonb_build_object(
    'desde', (select desde from cfg),
    'hasta', (select hasta from cfg),
    'serie', (select coalesce(jsonb_agg(to_jsonb(t) order by t.fecha), '[]'::jsonb) from serie t),
    'top',   (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from top t),
    'resumen', (select jsonb_build_object('pedidos', pedidos, 'ventas', ventas, 'ticket', ticket) from resumen where k = 'r'),
    'previo',  (select jsonb_build_object('pedidos', pedidos, 'ventas', ventas, 'ticket', ticket) from resumen where k = 'p')
  )
  where es_dueño_local(p_local_id);
$$;

grant execute on function reporte_local(uuid, date, date, date, date) to authenticated;


create or replace function historial_pedidos(
  p_local_id uuid,
  p_desde date default null,
  p_hasta date default null,
  p_estado text default null,
  p_limit int default 50,
  p_offset int default 0
)
returns jsonb
language sql stable security definer set search_path = public as $$
  with cfg as (
    select
      coalesce(
        p_desde,
        (select (l.created_at at time zone 'America/Argentina/Buenos_Aires')::date from locales l where l.id = p_local_id)
      ) as desde,
      coalesce(p_hasta, hoy_ar()) as hasta
  ),
  f as (
    select pe.*
    from pedidos pe, cfg
    where pe.local_id = p_local_id
      and (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date between cfg.desde and cfg.hasta
      and (p_estado is null or pe.estado = p_estado)
  )
  select jsonb_build_object(
    'total', (select count(*) from f),
    'pedidos', (
      select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
      from (
        select
          f.id, f.numero, f.created_at, f.nombre_cliente, f.telefono_cliente,
          f.total, f.estado, f.metodo_pago, f.tipo_entrega, f.direccion_barrio,
          (select count(*) from pedido_items pi where pi.pedido_id = f.id)::int as items
        from f
        order by f.created_at desc
        limit p_limit offset p_offset
      ) x
    )
  )
  where es_dueño_local(p_local_id);
$$;

grant execute on function historial_pedidos(uuid, date, date, text, int, int) to authenticated;
