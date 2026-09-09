-- historial_pedidos: agrega el id de cada pedido para poder abrir el detalle.
create or replace function historial_pedidos(
  p_local_id uuid,
  p_dias int default 30,
  p_estado text default null,
  p_limit int default 50,
  p_offset int default 0
)
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

grant execute on function historial_pedidos(uuid, int, text, int, int) to authenticated;
