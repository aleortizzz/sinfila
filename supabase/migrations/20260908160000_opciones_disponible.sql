-- ============================================================
-- Disponibilidad por opción de armado (ej. "me quedé sin cheddar").
-- opciones.disponible: la carta no muestra las que están en false, y
-- crear_pedido rechaza el pedido si el cliente mandó una (página vieja).
-- ============================================================

alter table opciones add column disponible boolean not null default true;

-- crear_pedido: mismo cuerpo que 20260908120000, con el rechazo de opciones
-- no disponibles agregado en la pasada 1.
create or replace function crear_pedido(p_payload jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_local locales%rowtype;
  v_item jsonb;
  v_producto productos%rowtype;
  v_combo combos%rowtype;
  v_opcion record;
  v_precio_unitario numeric(10,2);
  v_opciones_snapshot jsonb;
  v_pedido_id uuid;
  v_numero int;
  v_costo_delivery numeric(10,2) := 0;
  v_costo_zona numeric(10,2);
  v_cantidad int;
  v_items item_calculado[] := '{}';
  v_calc item_calculado;
begin
  if coalesce(trim(p_payload->>'nombre_cliente'), '') = '' then
    raise exception 'Falta el nombre';
  end if;
  if coalesce(trim(p_payload->>'telefono_cliente'), '') = '' then
    raise exception 'Falta el teléfono';
  end if;
  if jsonb_array_length(coalesce(p_payload->'items', '[]'::jsonb)) = 0 then
    raise exception 'El pedido no puede estar vacío';
  end if;

  select * into v_local from locales where slug = p_payload->>'local_slug';
  if not found or v_local.estado not in ('trial','activo','gracia') then
    raise exception 'Local no disponible';
  end if;

  if (p_payload->>'tipo_entrega') = 'retiro' and not v_local.acepta_retiro then
    raise exception 'Este local no acepta retiro en el local';
  elsif (p_payload->>'tipo_entrega') = 'delivery' and not v_local.acepta_delivery then
    raise exception 'Este local no hace delivery';
  end if;

  if (p_payload->>'metodo_pago') = 'efectivo' and not v_local.acepta_efectivo then
    raise exception 'Este local no acepta efectivo';
  elsif (p_payload->>'metodo_pago') = 'transferencia' and not v_local.acepta_transferencia then
    raise exception 'Este local no acepta transferencia';
  end if;

  if (p_payload->>'tipo_entrega') = 'delivery' then
    select costo into v_costo_zona from zonas_delivery
      where local_id = v_local.id and barrio = p_payload->'direccion'->>'barrio';
    if not found then
      raise exception 'No hacemos delivery a ese barrio';
    end if;
    v_costo_delivery := case when v_local.delivery_costo_modo = 'por_barrio'
      then v_costo_zona else v_local.delivery_costo_fijo end;
  end if;

  insert into pedidos (
    local_id, tipo_entrega, metodo_pago, nombre_cliente, telefono_cliente,
    direccion_calle, direccion_numero, direccion_piso_depto, direccion_barrio,
    direccion_referencia, direccion_maps_url, costo_delivery
  ) values (
    v_local.id,
    p_payload->>'tipo_entrega',
    p_payload->>'metodo_pago',
    trim(p_payload->>'nombre_cliente'),
    trim(p_payload->>'telefono_cliente'),
    p_payload->'direccion'->>'calle',
    p_payload->'direccion'->>'numero',
    p_payload->'direccion'->>'piso_depto',
    p_payload->'direccion'->>'barrio',
    p_payload->'direccion'->>'referencia',
    p_payload->'direccion'->>'maps_url',
    v_costo_delivery
  )
  returning id, numero into v_pedido_id, v_numero;

  -- Pasada 1: resolver cada ítem (precio real, opciones, estación).
  for v_item in select * from jsonb_array_elements(p_payload->'items')
  loop
    v_cantidad := coalesce((v_item->>'cantidad')::int, 1);
    if v_cantidad <= 0 then
      raise exception 'Cantidad inválida';
    end if;

    if (v_item->>'tipo') = 'producto' then
      select * into v_producto from productos
        where id = (v_item->>'ref_id')::uuid and local_id = v_local.id and disponible;
      if not found then
        raise exception 'Un producto del pedido ya no está disponible';
      end if;

      -- Opción elegida que se agotó (página vieja del cliente).
      if exists (
        select 1 from opciones o
        join grupos_opciones g on g.id = o.grupo_opcion_id
        where g.producto_id = v_producto.id
          and not o.disponible
          and o.id::text in (
            select jsonb_array_elements_text(coalesce(v_item->'opciones', '[]'::jsonb))
          )
      ) then
        raise exception 'Una opción que elegiste ya no está disponible';
      end if;

      v_precio_unitario := v_producto.precio;
      v_opciones_snapshot := '[]'::jsonb;

      for v_opcion in
        select o.nombre, o.precio_ajuste, g.nombre as grupo_nombre
        from opciones o
        join grupos_opciones g on g.id = o.grupo_opcion_id
        where g.producto_id = v_producto.id
          and o.disponible
          and o.id::text in (
            select jsonb_array_elements_text(coalesce(v_item->'opciones', '[]'::jsonb))
          )
      loop
        v_precio_unitario := v_precio_unitario + v_opcion.precio_ajuste;
        v_opciones_snapshot := v_opciones_snapshot || jsonb_build_object(
          'grupo', v_opcion.grupo_nombre,
          'opcion', v_opcion.nombre,
          'precio_ajuste', v_opcion.precio_ajuste
        );
      end loop;

      v_items := v_items || row(
        'producto', v_producto.id, null, v_producto.nombre, v_precio_unitario,
        v_cantidad, v_producto.estacion, v_opciones_snapshot, null, 0
      )::item_calculado;

    elsif (v_item->>'tipo') = 'combo' then
      select * into v_combo from combos
        where id = (v_item->>'ref_id')::uuid and local_id = v_local.id and disponible;
      if not found then
        raise exception 'Un combo del pedido ya no está disponible';
      end if;

      v_items := v_items || row(
        'combo', null, v_combo.id, v_combo.nombre, v_combo.precio,
        v_cantidad, v_combo.estacion, '[]'::jsonb, null, 0
      )::item_calculado;
    else
      raise exception 'Tipo de ítem inválido';
    end if;
  end loop;

  -- Pasada 2: promos, ya viendo el pedido completo.
  v_items := calcular_descuentos_promo(v_local.id, v_items);

  -- Pasada 3: insertar con promo_id/descuento resueltos.
  foreach v_calc in array v_items
  loop
    insert into pedido_items (
      pedido_id, tipo, producto_id, combo_id, nombre, precio_unitario, cantidad,
      estacion, opciones_elegidas, promo_id, descuento_aplicado
    ) values (
      v_pedido_id, v_calc.tipo, v_calc.producto_id, v_calc.combo_id, v_calc.nombre,
      v_calc.precio_unitario, v_calc.cantidad, v_calc.estacion, v_calc.opciones_elegidas,
      v_calc.promo_id, v_calc.descuento_aplicado
    );
  end loop;

  return jsonb_build_object('id', v_pedido_id, 'numero', v_numero);
end;
$$;
