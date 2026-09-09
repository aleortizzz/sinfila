-- ============================================================
-- reporte_local: se le suma el resumen del período (pedidos / ventas /
-- ticket promedio) y el mismo resumen del período ANTERIOR (misma
-- cantidad de días, justo antes) para poder mostrar la comparación.
-- Se saca "recientes" (eso vive ahora en historial_pedidos).
-- ============================================================

drop function if exists reporte_local(uuid, int);

create or replace function reporte_local(p_local_id uuid, p_dias int default 30)
returns jsonb
language sql stable security definer set search_path = public as $$
  with creado as (
    select (l.created_at at time zone 'America/Argentina/Buenos_Aires')::date as fecha
    from locales l where l.id = p_local_id
  ),
  cfg as (
    select
      case
        when p_dias > 0 then greatest((hoy_ar() - (p_dias - 1)), (select fecha from creado))
        else (select fecha from creado)
      end as desde,
      hoy_ar() as hasta
  ),
  win as (select desde, hasta, (hasta - desde + 1) as ndias from cfg),
  prev as (select (desde - ndias) as pdesde, (desde - 1) as phasta from win),
  ped as (
    select
      pe.id, pe.total,
      (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date as fecha
    from pedidos pe
    where pe.local_id = p_local_id
      and pe.estado not in ('rechazado', 'cancelado')
      and pe.created_at >= (select (pdesde - 1) from prev)
  ),
  base as (select p.* from ped p, win where p.fecha between win.desde and win.hasta),
  base_prev as (select p.* from ped p, prev where p.fecha between prev.pdesde and prev.phasta),
  dias as (select d::date as fecha from win, generate_series(win.desde, win.hasta, interval '1 day') d),
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
    'desde', (select desde from win),
    'hasta', (select hasta from win),
    'serie', (select coalesce(jsonb_agg(to_jsonb(t) order by t.fecha), '[]'::jsonb) from serie t),
    'top',   (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from top t),
    'resumen', (select jsonb_build_object('pedidos', pedidos, 'ventas', ventas, 'ticket', ticket) from resumen where k = 'r'),
    'previo',  (select jsonb_build_object('pedidos', pedidos, 'ventas', ventas, 'ticket', ticket) from resumen where k = 'p')
  )
  where es_dueño_local(p_local_id);
$$;

grant execute on function reporte_local(uuid, int) to authenticated;
