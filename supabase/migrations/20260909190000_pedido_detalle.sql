-- Detalle completo de un pedido para el historial del panel (dueño o staff).
create or replace function pedido_detalle(p_pedido_id uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'numero', pe.numero,
    'created_at', pe.created_at,
    'estado', pe.estado,
    'nombre_cliente', pe.nombre_cliente,
    'telefono_cliente', pe.telefono_cliente,
    'tipo_entrega', pe.tipo_entrega,
    'metodo_pago', pe.metodo_pago,
    'transferencia_avisada', pe.transferencia_avisada,
    'direccion', case when pe.tipo_entrega = 'delivery' then jsonb_build_object(
      'calle', pe.direccion_calle, 'numero', pe.direccion_numero,
      'piso_depto', pe.direccion_piso_depto, 'barrio', pe.direccion_barrio,
      'referencia', pe.direccion_referencia, 'maps_url', pe.direccion_maps_url
    ) end,
    'subtotal', pe.subtotal,
    'descuento_promos', pe.descuento_promos,
    'costo_delivery', pe.costo_delivery,
    'total', pe.total,
    'items', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'nombre', pi.nombre,
        'cantidad', pi.cantidad,
        'precio_unitario', pi.precio_unitario,
        'descuento_aplicado', pi.descuento_aplicado,
        'estacion', pi.estacion,
        'opciones', pi.opciones_elegidas
      ) order by pi.id), '[]'::jsonb)
      from pedido_items pi where pi.pedido_id = pe.id
    ),
    'historial', (
      select coalesce(jsonb_agg(jsonb_build_object('estado', es.estado, 'at', es.created_at) order by es.created_at), '[]'::jsonb)
      from pedido_estados es where es.pedido_id = pe.id
    )
  )
  from pedidos pe
  where pe.id = p_pedido_id and tiene_acceso_local(pe.local_id);
$$;

grant execute on function pedido_detalle(uuid) to authenticated;
