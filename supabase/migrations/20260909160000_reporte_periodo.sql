-- ============================================================
-- reporte_local ahora acepta un período: p_dias = 7 / 30 / 90, o <= 0 para
-- "desde que se creó el local". Antes era una ventana fija de 30 días.
-- ============================================================

drop function if exists reporte_local(uuid);

create or replace function reporte_local(p_local_id uuid, p_dias int default 30)
returns jsonb
language sql stable security definer set search_path = public as $$
  with cfg as (
    select
      case
        when p_dias > 0 then greatest(
          (hoy_ar() - (p_dias - 1)),
          (select (l.created_at at time zone 'America/Argentina/Buenos_Aires')::date from locales l where l.id = p_local_id)
        )
        else (select (l.created_at at time zone 'America/Argentina/Buenos_Aires')::date from locales l where l.id = p_local_id)
      end as desde,
      hoy_ar() as hasta
  ),
  base as (
    select
      pe.id, pe.numero, pe.created_at, pe.nombre_cliente, pe.total, pe.estado,
      pe.metodo_pago, pe.tipo_entrega,
      (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date as fecha
    from pedidos pe, cfg
    where pe.local_id = p_local_id
      and pe.estado not in ('rechazado', 'cancelado')
      and (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date between cfg.desde and cfg.hasta
  ),
  dias as (
    select d::date as fecha
    from cfg, generate_series(cfg.desde, cfg.hasta, interval '1 day') d
  ),
  serie as (
    select
      dias.fecha,
      count(b.id) as pedidos,
      coalesce(sum(b.total), 0)::numeric as ventas
    from dias
    left join base b on b.fecha = dias.fecha
    group by dias.fecha
  ),
  top as (
    select
      pi.nombre,
      sum(pi.cantidad)::int as unidades,
      sum((pi.precio_unitario - coalesce(pi.descuento_aplicado, 0)) * pi.cantidad)::numeric as monto
    from pedido_items pi
    join base b on b.id = pi.pedido_id
    group by pi.nombre
    order by unidades desc
    limit 10
  ),
  recientes as (
    select
      b.numero, b.created_at, b.nombre_cliente, b.total, b.estado,
      b.metodo_pago, b.tipo_entrega,
      (select count(*) from pedido_items pi where pi.pedido_id = b.id)::int as items
    from base b
    order by b.created_at desc
    limit 20
  )
  select jsonb_build_object(
    'serie',     (select coalesce(jsonb_agg(to_jsonb(t) order by t.fecha), '[]'::jsonb) from serie t),
    'top',       (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from top t),
    'recientes', (select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc), '[]'::jsonb) from recientes t)
  )
  where es_dueño_local(p_local_id);
$$;

grant execute on function reporte_local(uuid, int) to authenticated;
