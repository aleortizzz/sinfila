-- ============================================================
-- Tercer tipo de promo: 'porcentaje' (ej. -20%).
--
-- Por qué: 'precio_especial' fija un precio plano y solo sirve si todos los
-- productos de la promo valen parecido. Un "trago $8000 → $7000" está bien,
-- pero si la misma promo incluye papas de $5000 quedarían MÁS caras. El
-- porcentaje se adapta al precio de cada producto.
-- ============================================================

alter table promos add column descuento_pct numeric(5,2);

-- Ampliar los dos checks: el de la columna "tipo" y el de coherencia.
alter table promos drop constraint promos_tipo_check;
alter table promos add constraint promos_tipo_check
  check (tipo in ('nxm', 'precio_especial', 'porcentaje'));

alter table promos drop constraint promos_check;
alter table promos add constraint promos_check
  check (
    (tipo = 'nxm' and n is not null and m is not null and n > 0 and m >= 0 and n > m)
    or
    (tipo = 'precio_especial' and precio_especial is not null and precio_especial > 0)
    or
    (tipo = 'porcentaje' and descuento_pct is not null and descuento_pct > 0 and descuento_pct <= 100)
  );

-- calcular_descuentos_promo(): misma estructura que el Hito 9a, con la rama
-- 'porcentaje' sumada al score y al descuento final.
create or replace function calcular_descuentos_promo(p_local_id uuid, p_items item_calculado[])
returns item_calculado[]
language sql stable set search_path = public as $$
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
  candidatos as (
    select
      b.fila,
      pr.id as promo_id,
      pr.tipo,
      pr.n,
      pr.m,
      pr.precio_especial,
      pr.descuento_pct,
      case
        when pr.tipo = 'nxm' then (pr.n - pr.m)::numeric / pr.n
        when pr.tipo = 'porcentaje' then pr.descuento_pct / 100
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
  mejor as (
    select distinct on (fila) fila, promo_id, tipo, n, m, precio_especial, descuento_pct
    from candidatos
    order by fila, score desc
  ),
  asignado as (
    select
      b.*,
      mj.promo_id as promo_asignada,
      mj.tipo as promo_tipo,
      mj.n, mj.m, mj.precio_especial, mj.descuento_pct
    from base b
    left join mejor mj using (fila)
  ),
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
        when a.promo_tipo = 'porcentaje' then round(a.precio_unitario * a.descuento_pct / 100, 2)
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

-- Promos vigentes ahora mismo (día + franja horaria ya chequeados), con el
-- producto al que aplican. La carta lo usa para mostrar el precio con promo
-- sin tener que llamar a previsualizar_pedido por cada producto.
create or replace function promos_vigentes(p_local_id uuid)
returns table (
  producto_id uuid,
  promo_nombre text,
  tipo text,
  precio_especial numeric,
  descuento_pct numeric,
  n int,
  m int
)
language sql stable set search_path = public as $$
  with ahora as (
    select
      (now() at time zone 'America/Argentina/Buenos_Aires')::time as hora,
      extract(dow from (now() at time zone 'America/Argentina/Buenos_Aires'))::int as dow
  )
  select pp.producto_id, pr.nombre, pr.tipo, pr.precio_especial, pr.descuento_pct, pr.n, pr.m
  from promos pr
  join promo_productos pp on pp.promo_id = pr.id
  cross join ahora
  where pr.local_id = p_local_id
    and pr.activa
    and ahora.dow = any(pr.dias_semana)
    and ahora.hora between pr.hora_desde and pr.hora_hasta;
$$;

grant execute on function promos_vigentes(uuid) to anon, authenticated;
