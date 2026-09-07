-- Hito 7: el cliente sigue su pedido sin cuenta, con el link que le
-- dimos al confirmar (/pedido/<uuid>). Igual que crear_pedido, no
-- exponemos la tabla "pedidos" directo (dejaría listar pedidos ajenos) —
-- una función que exige conocer el UUID exacto (122 bits, no adivinable)
-- y devuelve solo lo que el cliente necesita ver.

create or replace function obtener_pedido_publico(p_id uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_pedido record;
  v_items jsonb;
begin
  select p.numero, p.estado, p.tipo_entrega, p.metodo_pago,
         p.nombre_cliente, p.subtotal, p.descuento_promos, p.costo_delivery,
         p.total, p.created_at, l.nombre as local_nombre
    into v_pedido
    from pedidos p
    join locales l on l.id = p.local_id
    where p.id = p_id;

  if not found then
    raise exception 'Pedido no encontrado';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'nombre', i.nombre, 'cantidad', i.cantidad,
        'precio_unitario', i.precio_unitario, 'opciones', i.opciones_elegidas
      ) order by i.created_at
    ), '[]'::jsonb
  )
  into v_items
  from pedido_items i
  where i.pedido_id = p_id;

  return jsonb_build_object(
    'numero', v_pedido.numero,
    'estado', v_pedido.estado,
    'tipo_entrega', v_pedido.tipo_entrega,
    'metodo_pago', v_pedido.metodo_pago,
    'nombre_cliente', v_pedido.nombre_cliente,
    'subtotal', v_pedido.subtotal,
    'descuento_promos', v_pedido.descuento_promos,
    'costo_delivery', v_pedido.costo_delivery,
    'total', v_pedido.total,
    'local_nombre', v_pedido.local_nombre,
    'items', v_items
  );
end;
$$;

revoke execute on function obtener_pedido_publico(uuid) from public;
grant execute on function obtener_pedido_publico(uuid) to anon, authenticated;
