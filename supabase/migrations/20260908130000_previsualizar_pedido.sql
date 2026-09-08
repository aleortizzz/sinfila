-- ============================================================
-- previsualizar_pedido(): mismo cálculo que crear_pedido (precio real +
-- opciones + motor de promos), pero SIN insertar nada. Lo usa el checkout
-- para mostrar el descuento de promo ANTES de pagar.
--
-- La fuente de verdad sigue siendo crear_pedido: esto es solo un preview,
-- se puede llamar cuantas veces haga falta y no tiene efectos. Comparte el
-- tipo item_calculado y la función calcular_descuentos_promo() del Hito 9a,
-- así que el número que muestra el checkout es exactamente el que se cobra.
--
-- No valida tan duro como crear_pedido (un ítem que ya no está disponible
-- se saltea en vez de tirar excepción) — la validación real la hace
-- crear_pedido al confirmar.
-- ============================================================

create or replace function previsualizar_pedido(p_payload jsonb)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_local locales%rowtype;
  v_item jsonb;
  v_producto productos%rowtype;
  v_combo combos%rowtype;
  v_opcion record;
  v_precio_unitario numeric(10,2);
  v_cantidad int;
  v_items item_calculado[] := '{}';
  v_calc item_calculado;
  v_subtotal numeric(10,2) := 0;
  v_descuento numeric(10,2) := 0;
  v_lineas jsonb := '[]'::jsonb;
begin
  select * into v_local from locales where slug = p_payload->>'local_slug';
  if not found or v_local.estado not in ('trial','activo','gracia') then
    raise exception 'Local no disponible';
  end if;

  -- Pasada 1: resolver cada ítem (precio real + opciones), sin insertar.
  for v_item in select * from jsonb_array_elements(coalesce(p_payload->'items', '[]'::jsonb))
  loop
    v_cantidad := coalesce((v_item->>'cantidad')::int, 1);
    if v_cantidad <= 0 then
      continue;
    end if;

    if (v_item->>'tipo') = 'producto' then
      select * into v_producto from productos
        where id = (v_item->>'ref_id')::uuid and local_id = v_local.id and disponible;
      if not found then
        continue;
      end if;

      v_precio_unitario := v_producto.precio;
      for v_opcion in
        select o.precio_ajuste
        from opciones o
        join grupos_opciones g on g.id = o.grupo_opcion_id
        where g.producto_id = v_producto.id
          and o.id::text in (
            select jsonb_array_elements_text(coalesce(v_item->'opciones', '[]'::jsonb))
          )
      loop
        v_precio_unitario := v_precio_unitario + v_opcion.precio_ajuste;
      end loop;

      v_items := v_items || row(
        'producto', v_producto.id, null, v_producto.nombre, v_precio_unitario,
        v_cantidad, v_producto.estacion, '[]'::jsonb, null, 0
      )::item_calculado;

    elsif (v_item->>'tipo') = 'combo' then
      select * into v_combo from combos
        where id = (v_item->>'ref_id')::uuid and local_id = v_local.id and disponible;
      if not found then
        continue;
      end if;

      v_items := v_items || row(
        'combo', null, v_combo.id, v_combo.nombre, v_combo.precio,
        v_cantidad, v_combo.estacion, '[]'::jsonb, null, 0
      )::item_calculado;
    end if;
  end loop;

  -- Pasada 2: promos (mismo motor que crear_pedido).
  v_items := calcular_descuentos_promo(v_local.id, v_items);

  foreach v_calc in array v_items
  loop
    v_subtotal := v_subtotal + v_calc.precio_unitario * v_calc.cantidad;
    v_descuento := v_descuento + v_calc.descuento_aplicado * v_calc.cantidad;
    v_lineas := v_lineas || jsonb_build_object(
      'nombre', v_calc.nombre,
      'cantidad', v_calc.cantidad,
      'precio_unitario', v_calc.precio_unitario,
      'descuento_unitario', v_calc.descuento_aplicado,
      'tiene_promo', v_calc.promo_id is not null
    );
  end loop;

  return jsonb_build_object(
    'subtotal', v_subtotal,
    'descuento_promos', v_descuento,
    'total', v_subtotal - v_descuento,
    'items', v_lineas
  );
end;
$$;

grant execute on function previsualizar_pedido(jsonb) to anon, authenticated;
