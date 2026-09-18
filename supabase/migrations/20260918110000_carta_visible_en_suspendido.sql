-- ============================================================
-- Pedido del usuario: un local "suspendido" (venció la gracia sin pagar)
-- hoy desaparece del todo de la carta pública — un cliente que ya
-- conocía el link ve "no encontramos este local", como si nunca hubiera
-- existido. Se cambia para que la carta se siga viendo (marcada como
-- cerrada, sin poder pedir) — mejor para la reputación del negocio y
-- para que un cliente con el link guardado no piense que cerró para
-- siempre por un problema de facturación.
--
-- Separado de esto: un toggle nuevo, exclusivo del super-admin, para
-- ocultar la carta del todo cuando de verdad hace falta (pedido
-- explícito del dueño de bajarla, disputa, etc.) — independiente del
-- estado de la suscripción. `carta_deshabilitada = true` reproduce el
-- comportamiento actual de "suspendido" (desaparece por completo).
-- ============================================================

alter table locales add column carta_deshabilitada boolean not null default false;

create or replace function local_visible_publicamente(p_local_id uuid)
returns boolean
language sql stable as $$
  select estado in ('trial','activo','gracia','suspendido') and not carta_deshabilitada
  from locales where id = p_local_id;
$$;

-- crear_pedido ya rechazaba pedidos si el estado no es trial/activo/gracia
-- (ver 20260907160000_crear_pedido.sql) — esa parte no cambia, así que un
-- local "suspendido" sigue sin poder recibir pedidos aunque ahora se vea
-- la carta. Acá solo se suma el chequeo de carta_deshabilitada, para que
-- tampoco se pueda pedir si el super-admin la bajó a mano.
create or replace function crear_pedido(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_local locales%rowtype;
  v_item jsonb;
  v_producto productos%rowtype;
  v_combo combos%rowtype;
  v_opcion record;
  v_precio_unitario numeric(10,2);
  v_opciones_snapshot jsonb;
  v_opcion_ids uuid[];
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
  if not found or v_local.estado not in ('trial','activo','gracia') or v_local.carta_deshabilitada then
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

    select coalesce(array_agg(x::uuid), '{}')
      into v_opcion_ids
      from jsonb_array_elements_text(coalesce(v_item->'opciones', '[]'::jsonb)) x;

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
          and o.id = any(v_opcion_ids)
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
        v_cantidad, v_combo.estacion,
        resolver_opciones_combo(v_combo.id, v_opcion_ids, true),
        null, 0
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
$function$;

-- Toggle exclusivo del super-admin, independiente de la suscripción.
create or replace function alternar_carta_local(p_local_id uuid, p_deshabilitada boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not es_super_admin() then
    raise exception 'Solo el super-admin puede hacer esto.';
  end if;
  update locales set carta_deshabilitada = p_deshabilitada where id = p_local_id;
  if not found then
    raise exception 'Local no encontrado';
  end if;
end;
$$;

revoke execute on function alternar_carta_local(uuid, boolean) from public;
grant execute on function alternar_carta_local(uuid, boolean) to authenticated;

-- listar_locales_superadmin necesita mostrar el estado de este toggle.
drop function if exists listar_locales_superadmin();
create or replace function listar_locales_superadmin()
returns table (
  local_id uuid,
  local_nombre text,
  slug text,
  estado text,
  negocio_nombre text,
  email_contacto text,
  precio_mensual numeric,
  trial_hasta date,
  proximo_vencimiento date,
  gracia_hasta date,
  carta_deshabilitada boolean,
  creado timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    l.id, l.nombre, l.slug, l.estado,
    n.nombre, n.email_contacto,
    l.precio_mensual, l.trial_hasta, l.proximo_vencimiento, l.gracia_hasta,
    l.carta_deshabilitada,
    l.created_at
  from locales l
  join negocios n on n.id = l.negocio_id
  where es_super_admin()
  order by l.created_at desc;
$$;

grant execute on function listar_locales_superadmin() to authenticated;
