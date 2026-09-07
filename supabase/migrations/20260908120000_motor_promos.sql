-- ============================================================
-- Hito 9: motor de promos (NxM y precio especial), aplicado en
-- crear_pedido(). Nunca se confía en el cliente para esto — se recalcula
-- todo del lado del servidor, igual que precios y disponibilidad.
--
-- Regla de "sin apilar" (decidida en el discovery): un producto puede
-- estar en varias promos vigentes a la vez, pero se le aplica UNA sola —
-- la que le da mejor descuento a ESE producto puntual.
--
-- Un NxM (3x2, etc.) se calcula agrupando TODAS las líneas del pedido que
-- quedaron asignadas a esa misma promo (pueden ser productos distintos:
-- "3x2 en tragos de $8000" cuenta juntos el fernet y el speed si los dos
-- entran en esa promo), no por producto aislado.
-- ============================================================

-- Endurecemos un poco el check de 2a: n/m tienen que ser valores sanos
-- (evita división por cero y promos sin sentido tipo n=0 o precio <= 0).
alter table promos drop constraint promos_check;
alter table promos add constraint promos_check
  check (
    (tipo = 'nxm' and n is not null and m is not null and n > 0 and m >= 0 and n > m)
    or
    (tipo = 'precio_especial' and precio_especial is not null and precio_especial > 0)
  );

-- Tipo auxiliar: un ítem de pedido ya resuelto (precio/nombre/estación
-- calculados), antes de decidir qué promo le toca y de insertarlo. La
-- posición dentro del pedido la trackea "with ordinality" al usarlo, no
-- hace falta guardarla acá adentro.
create type item_calculado as (
  tipo text,
  producto_id uuid,
  combo_id uuid,
  nombre text,
  precio_unitario numeric,
  cantidad int,
  estacion text,
  opciones_elegidas jsonb,
  promo_id uuid,
  descuento_aplicado numeric
);

-- Toma los ítems ya resueltos (sin promo todavía) y les completa
-- promo_id / descuento_aplicado. Es una consulta, no un procedimiento: más
-- fácil de razonar y de probar que un loop imperativo.
create or replace function calcular_descuentos_promo(p_local_id uuid, p_items item_calculado[])
returns item_calculado[]
language sql stable set search_path = public as $$
  -- unnest() de un array de tipo compuesto ya lo desarma en columnas (no
  -- hace falta "(t.u).*" — eso desalinea todo, ord termina pisando el
  -- primer campo real). Por eso acá van los 10 campos + "fila" al final.
  with base as (
    select *
    from unnest(p_items) with ordinality as t(
      tipo, producto_id, combo_id, nombre, precio_unitario, cantidad,
      estacion, opciones_elegidas, promo_id, descuento_aplicado, fila
    )
  ),
  ahora as (
    select
      (now() at time zone 'America/Argentina/Buenos_Aires')::time as hora,
      extract(dow from (now() at time zone 'America/Argentina/Buenos_Aires'))::int as dow
  ),
  -- Todas las promos vigentes ahora mismo que incluyen a cada ítem
  -- (solo aplica a productos sueltos, nunca a combos), con un puntaje
  -- de "qué tan buena es" para ese ítem puntual.
  candidatos as (
    select
      b.fila,
      pr.id as promo_id,
      pr.tipo,
      pr.n,
      pr.m,
      pr.precio_especial,
      case
        when pr.tipo = 'nxm' then (pr.n - pr.m)::numeric / pr.n
        else greatest(0, 1 - pr.precio_especial / nullif(b.precio_unitario, 0))
      end as score
    from base b
    join promo_productos pp on pp.producto_id = b.producto_id
    join promos pr on pr.id = pp.promo_id and pr.local_id = p_local_id
    cross join ahora
    where b.tipo = 'producto'
      and pr.activa
      and ahora.dow = any(pr.dias_semana)
      and ahora.hora between pr.hora_desde and pr.hora_hasta
  ),
  -- Una sola promo por ítem: la de mejor puntaje (sin apilar).
  mejor as (
    select distinct on (fila) fila, promo_id, tipo, n, m, precio_especial
    from candidatos
    order by fila, score desc
  ),
  asignado as (
    select b.*, mj.promo_id as promo_asignada, mj.tipo as promo_tipo, mj.n, mj.m, mj.precio_especial
    from base b
    left join mejor mj using (fila)
  ),
  -- NxM: se agrupa por promo entre TODAS las líneas asignadas a ella
  -- (puede ser más de un producto). El descuento por unidad sale de
  -- repartir el valor de las unidades gratis proporcional a la cantidad
  -- total del grupo — con precios iguales (el caso real: "tragos de
  -- $8000") da exactamente lo mismo que "las unidades más baratas gratis".
  grupos_nxm as (
    select
      promo_asignada,
      sum(cantidad) as total_qty,
      sum(precio_unitario * cantidad) as total_valor,
      floor(sum(cantidad)::numeric / max(n)) * max(n - m) as free_qty
    from asignado
    where promo_tipo = 'nxm'
    group by promo_asignada
  ),
  final as (
    select
      a.fila, a.tipo, a.producto_id, a.combo_id, a.nombre, a.precio_unitario, a.cantidad,
      a.estacion, a.opciones_elegidas,
      a.promo_asignada as promo_id,
      case
        when a.promo_tipo = 'precio_especial' then greatest(0, a.precio_unitario - a.precio_especial)
        when a.promo_tipo = 'nxm' and g.total_qty > 0 then
          round((g.free_qty::numeric * (g.total_valor / g.total_qty)) / g.total_qty, 2)
        else 0
      end as descuento_aplicado
    from asignado a
    left join grupos_nxm g on g.promo_asignada = a.promo_asignada
  )
  select array_agg(
    row(
      tipo, producto_id, combo_id, nombre, precio_unitario, cantidad,
      estacion, opciones_elegidas, promo_id, descuento_aplicado
    )::item_calculado
    order by fila
  )
  from final;
$$;

-- crear_pedido: igual que antes para resolver local/entrega/pago/delivery,
-- pero ahora arma un array de ítems resueltos, le pide el descuento a
-- calcular_descuentos_promo(), y RECIÉN AHÍ inserta en pedido_items.
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

  -- Pasada 1: resolver cada ítem (precio real, opciones, estación) sin
  -- insertar todavía — hace falta ver el pedido completo antes de decidir
  -- las promos (un NxM cuenta entre varias líneas a la vez).
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

      v_precio_unitario := v_producto.precio;
      v_opciones_snapshot := '[]'::jsonb;

      for v_opcion in
        select o.nombre, o.precio_ajuste, g.nombre as grupo_nombre
        from opciones o
        join grupos_opciones g on g.id = o.grupo_opcion_id
        where g.producto_id = v_producto.id
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

  -- Pasada 3: recién ahora se inserta, ya con promo_id/descuento resueltos.
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
