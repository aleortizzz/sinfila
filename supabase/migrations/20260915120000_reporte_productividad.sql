-- ============================================================
-- Reporte de productividad: pedidos manejados por persona, tiempo
-- promedio de preparación por persona, y un tiempo promedio general del
-- local. Usa pedido_estados.changed_by, que ya venía grabándose desde el
-- Hito 2b — no hace falta ningún tracking nuevo, solo consultar lo que
-- ya está.
--
-- "en_preparacion -> listo" mide cuánto tarda esa persona en dejar listo
-- un pedido una vez que empezó a prepararlo. El "listo" automático (lo
-- dispara la última estación en terminar, vía promover_estado_si_listo())
-- ya atribuye correctamente a quien lo completó — no hace falta lógica
-- extra para eso.
-- ============================================================

create or replace function reporte_productividad(
  p_local_id uuid,
  p_desde date default null,
  p_hasta date default null
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
    select id, created_at
    from pedidos, cfg
    where local_id = p_local_id
      and estado not in ('rechazado', 'cancelado')
      and (created_at at time zone 'America/Argentina/Buenos_Aires')::date between cfg.desde and cfg.hasta
  ),
  ep as (
    select distinct on (pedido_id) pedido_id, created_at as en_prep_at
    from pedido_estados
    where estado = 'en_preparacion' and pedido_id in (select id from ped)
    order by pedido_id, created_at asc
  ),
  li as (
    select distinct on (pedido_id) pedido_id, created_at as listo_at, changed_by
    from pedido_estados
    where estado = 'listo' and pedido_id in (select id from ped)
    order by pedido_id, created_at asc
  ),
  duraciones as (
    select
      ped.id as pedido_id,
      extract(epoch from (li.listo_at - ep.en_prep_at)) as seg_preparacion,
      extract(epoch from (li.listo_at - ped.created_at)) as seg_total,
      li.changed_by
    from ped
    left join ep on ep.pedido_id = ped.id
    left join li on li.pedido_id = ped.id
  ),
  toques as (
    select distinct pe.changed_by, pe.pedido_id
    from pedido_estados pe
    where pe.pedido_id in (select id from ped) and pe.changed_by is not null
  ),
  por_persona as (
    select
      t.changed_by as usuario_id,
      count(distinct t.pedido_id) as pedidos_manejados,
      avg(d.seg_preparacion) filter (where d.changed_by = t.changed_by and d.seg_preparacion is not null) as seg_prep_promedio
    from toques t
    left join duraciones d on d.pedido_id = t.pedido_id
    group by t.changed_by
  )
  select jsonb_build_object(
    'desde', (select desde from cfg),
    'hasta', (select hasta from cfg),
    'general', jsonb_build_object(
      'pedidos_completados', (select count(*) from duraciones where seg_total is not null),
      'seg_promedio_total', (select avg(seg_total) from duraciones where seg_total is not null)
    ),
    'por_persona', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'usuario_id', pp.usuario_id,
        'email', u.email,
        'nombre', ulr.nombre,
        'pedidos_manejados', pp.pedidos_manejados,
        'seg_prep_promedio', pp.seg_prep_promedio
      ) order by pp.pedidos_manejados desc), '[]'::jsonb)
      from por_persona pp
      left join auth.users u on u.id = pp.usuario_id
      left join usuario_local_roles ulr on ulr.usuario_id = pp.usuario_id and ulr.local_id = p_local_id
    )
  )
  where puede_ver_facturacion(p_local_id);
$$;

grant execute on function reporte_productividad(uuid, date, date) to authenticated;
