-- ============================================================
-- reporte_local suma p_incluir_envio (default true).
--  · true  => "facturación" = total del pedido (neto de promo + envío) — como hasta ahora.
--  · false => se le resta costo_delivery: solo lo que se facturó de productos.
-- Solo tiene efecto sin filtro de categoría (con categoría el envío ya
-- queda afuera porque se mira ítem por ítem).
-- ============================================================

drop function if exists reporte_local(uuid, date, date, date, date, uuid);

create or replace function reporte_local(
  p_local_id uuid,
  p_desde date default null,
  p_hasta date default null,
  p_prev_desde date default null,
  p_prev_hasta date default null,
  p_categoria_id uuid default null,
  p_incluir_envio boolean default true
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
      pe.id, pe.total, pe.costo_delivery,
      (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date as fecha
    from pedidos pe, cfg
    where pe.local_id = p_local_id
      and pe.estado not in ('rechazado', 'cancelado')
      and pe.created_at >= (coalesce(p_prev_desde, (select desde from cfg))::timestamptz - interval '2 days')
  ),
  -- Ítems de la categoría filtrada (solo se usa si p_categoria_id no es null).
  it as (
    select
      pe.id as pedido_id, pe.fecha,
      (pi.precio_unitario - coalesce(pi.descuento_aplicado, 0)) * pi.cantidad as monto
    from ped pe
    join pedido_items pi on pi.pedido_id = pe.id
    join productos pr on pr.id = pi.producto_id
    where pr.categoria_id = p_categoria_id
  ),
  -- "filas" del período: una por pedido (sin filtro) o una por ítem de la categoría.
  base as (
    select p.id as pedido_id, p.fecha,
      (p.total - case when p_incluir_envio then 0 else p.costo_delivery end) as monto
    from ped p, cfg
    where p_categoria_id is null and p.fecha between cfg.desde and cfg.hasta
    union all
    select i.pedido_id, i.fecha, i.monto
    from it i, cfg
    where p_categoria_id is not null and i.fecha between cfg.desde and cfg.hasta
  ),
  base_prev as (
    select p.id as pedido_id, p.fecha,
      (p.total - case when p_incluir_envio then 0 else p.costo_delivery end) as monto
    from ped p
    where p_categoria_id is null and p_prev_desde is not null
      and p.fecha between p_prev_desde and p_prev_hasta
    union all
    select i.pedido_id, i.fecha, i.monto
    from it i
    where p_categoria_id is not null and p_prev_desde is not null
      and i.fecha between p_prev_desde and p_prev_hasta
  ),
  dias as (select d::date as fecha from cfg, generate_series(cfg.desde, cfg.hasta, interval '1 day') d),
  serie as (
    select
      dias.fecha,
      count(distinct b.pedido_id) as pedidos,
      coalesce(sum(b.monto), 0)::numeric as ventas
    from dias left join base b on b.fecha = dias.fecha
    group by dias.fecha
  ),
  top as (
    select
      pi.nombre,
      sum(pi.cantidad)::int as unidades,
      sum((pi.precio_unitario - coalesce(pi.descuento_aplicado, 0)) * pi.cantidad)::numeric as monto
    from pedido_items pi
    join (select distinct pedido_id from base) b on b.pedido_id = pi.pedido_id
    left join productos pr on pr.id = pi.producto_id
    where p_categoria_id is null or pr.categoria_id = p_categoria_id
    group by pi.nombre order by unidades desc limit 10
  ),
  resumen as (
    select 'r' as k,
      count(distinct pedido_id) as pedidos,
      coalesce(sum(monto), 0)::numeric as ventas,
      case when count(distinct pedido_id) > 0 then round(sum(monto) / count(distinct pedido_id)) else 0 end as ticket
    from base
    union all
    select 'p',
      count(distinct pedido_id),
      coalesce(sum(monto), 0)::numeric,
      case when count(distinct pedido_id) > 0 then round(sum(monto) / count(distinct pedido_id)) else 0 end
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

grant execute on function reporte_local(uuid, date, date, date, date, uuid, boolean) to authenticated;
