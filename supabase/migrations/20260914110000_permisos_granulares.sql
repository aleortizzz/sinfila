-- ============================================================
-- Permisos granulares por persona del equipo.
--
-- Decisión de diseño (conversación con el usuario, 2026-09-14): NO un
-- sistema abierto de checkboxes libres. Son 2 interruptores independientes
-- en `usuario_local_roles`, que combinados dan las 4 combinaciones reales
-- de un local (ninguno = staff de hoy; ambos = encargado; solo facturación
-- = quien cierra caja; solo menú = alguien que arma la carta sin ver plata).
-- "Gestionar equipo" y "Configuración" quedan SIEMPRE dueño-only, sin
-- excepción — a propósito, para que no exista la posibilidad de que
-- alguien se autoasigne más permisos vía este mismo mecanismo.
-- ============================================================

alter table usuario_local_roles
  add column ve_facturacion boolean not null default false,
  add column edita_menu boolean not null default false;

create or replace function puede_ver_facturacion(p_local_id uuid)
returns boolean
language sql stable as $$
  select es_dueño_local(p_local_id) or exists (
    select 1 from usuario_local_roles
    where local_id = p_local_id and usuario_id = auth.uid() and ve_facturacion
  );
$$;

create or replace function puede_editar_menu(p_local_id uuid)
returns boolean
language sql stable as $$
  select es_dueño_local(p_local_id) or exists (
    select 1 from usuario_local_roles
    where local_id = p_local_id and usuario_id = auth.uid() and edita_menu
  );
$$;

-- --- Reportes / estadísticas / historial: es_dueño_local -> puede_ver_facturacion ---
-- (mismos cuerpos que ya estaban, solo cambia el guard final)

create or replace function estadisticas_local(p_local_id uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  with lim as (
    select
      hoy_ar() as hoy,
      (hoy_ar() - 6) as hace_7,
      date_trunc('month', hoy_ar())::date as inicio_mes
  ),
  p as (
    select
      pe.total,
      (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date as fecha
    from pedidos pe, lim
    where pe.local_id = p_local_id
      and pe.estado not in ('rechazado', 'cancelado')
      and (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date >= lim.inicio_mes
  )
  select jsonb_build_object(
    'pedidos_hoy',       (select count(*) from p, lim where p.fecha = lim.hoy),
    'ventas_hoy',        (select coalesce(sum(total), 0) from p, lim where p.fecha = lim.hoy),
    'pedidos_7d',        (select count(*) from p, lim where p.fecha >= lim.hace_7),
    'ventas_7d',         (select coalesce(sum(total), 0) from p, lim where p.fecha >= lim.hace_7),
    'ventas_mes',        (select coalesce(sum(total), 0) from p),
    'productos_activos', (select count(*) from productos where local_id = p_local_id and disponible)
  )
  where puede_ver_facturacion(p_local_id);
$$;

create or replace function historial_pedidos(
  p_local_id uuid,
  p_desde date default null,
  p_hasta date default null,
  p_estado text default null,
  p_limit int default 50,
  p_offset int default 0
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
  where puede_ver_facturacion(p_local_id);
$$;

create or replace function reporte_local(
  p_local_id uuid,
  p_desde date default null,
  p_hasta date default null,
  p_prev_desde date default null,
  p_prev_hasta date default null,
  p_categoria_id uuid default null,
  p_incluir_envio boolean default true
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
    select
      pe.id, pe.total, pe.costo_delivery,
      (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date as fecha
    from pedidos pe, cfg
    where pe.local_id = p_local_id
      and pe.estado not in ('rechazado', 'cancelado')
      and pe.created_at >= (coalesce(p_prev_desde, (select desde from cfg))::timestamptz - interval '2 days')
  ),
  it as (
    select
      pe.id as pedido_id, pe.fecha,
      (pi.precio_unitario - coalesce(pi.descuento_aplicado, 0)) * pi.cantidad as monto
    from ped pe
    join pedido_items pi on pi.pedido_id = pe.id
    join productos pr on pr.id = pi.producto_id
    where pr.categoria_id = p_categoria_id
  ),
  base as (
    select p.id as pedido_id, p.fecha,
      (p.total - case when p_incluir_envio then 0 else p.costo_delivery end) as monto
    from ped p, cfg
    where p_categoria_id is null and p.fecha between cfg.desde and cfg.hasta
    union all
    select i.pedido_id, i.fecha, i.monto
    from it i, cfg
    where p_categoria_id is not null and i.fecha between cfg.desde and cfg.hasta
  ),
  base_prev as (
    select p.id as pedido_id, p.fecha,
      (p.total - case when p_incluir_envio then 0 else p.costo_delivery end) as monto
    from ped p
    where p_categoria_id is null and p_prev_desde is not null
      and p.fecha between p_prev_desde and p_prev_hasta
    union all
    select i.pedido_id, i.fecha, i.monto
    from it i
    where p_categoria_id is not null and p_prev_desde is not null
      and i.fecha between p_prev_desde and p_prev_hasta
  ),
  dias as (select d::date as fecha from cfg, generate_series(cfg.desde, cfg.hasta, interval '1 day') d),
  serie as (
    select
      dias.fecha,
      count(distinct b.pedido_id) as pedidos,
      coalesce(sum(b.monto), 0)::numeric as ventas
    from dias left join base b on b.fecha = dias.fecha
    group by dias.fecha
  ),
  top as (
    select
      pi.nombre,
      sum(pi.cantidad)::int as unidades,
      sum((pi.precio_unitario - coalesce(pi.descuento_aplicado, 0)) * pi.cantidad)::numeric as monto
    from pedido_items pi
    join (select distinct pedido_id from base) b on b.pedido_id = pi.pedido_id
    left join productos pr on pr.id = pi.producto_id
    where p_categoria_id is null or pr.categoria_id = p_categoria_id
    group by pi.nombre order by unidades desc limit 10
  ),
  resumen as (
    select 'r' as k,
      count(distinct pedido_id) as pedidos,
      coalesce(sum(monto), 0)::numeric as ventas,
      case when count(distinct pedido_id) > 0 then round(sum(monto) / count(distinct pedido_id)) else 0 end as ticket
    from base
    union all
    select 'p',
      count(distinct pedido_id),
      coalesce(sum(monto), 0)::numeric,
      case when count(distinct pedido_id) > 0 then round(sum(monto) / count(distinct pedido_id)) else 0 end
    from base_prev
  )
  select jsonb_build_object(
    'desde', (select desde from cfg),
    'hasta', (select hasta from cfg),
    'serie', (select coalesce(jsonb_agg(to_jsonb(t) order by t.fecha), '[]'::jsonb) from serie t),
    'top',   (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from top t),
    'resumen', (select jsonb_build_object('pedidos', pedidos, 'ventas', ventas, 'ticket', ticket) from resumen where k = 'r'),
    'previo',  (select jsonb_build_object('pedidos', pedidos, 'ventas', ventas, 'ticket', ticket) from resumen where k = 'p')
  )
  where puede_ver_facturacion(p_local_id);
$$;

create or replace function top_productos_local(p_local_id uuid, p_desde date, p_hasta date, p_categoria_id uuid default null)
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
  from (
    select
      pi.nombre,
      sum(pi.cantidad)::int as unidades,
      sum((pi.precio_unitario - coalesce(pi.descuento_aplicado, 0)) * pi.cantidad)::numeric as monto
    from pedido_items pi
    join pedidos pe on pe.id = pi.pedido_id
    left join productos pr on pr.id = pi.producto_id
    where pe.local_id = p_local_id
      and pe.estado not in ('rechazado', 'cancelado')
      and (pe.created_at at time zone 'America/Argentina/Buenos_Aires')::date between p_desde and p_hasta
      and (p_categoria_id is null or pr.categoria_id = p_categoria_id)
    group by pi.nombre
    order by unidades desc
    limit 10
  ) t
  where puede_ver_facturacion(p_local_id);
$$;

-- --- Menú (productos/combos/opciones/promos): es_dueño_local -> puede_editar_menu ---

alter policy categorias_write on categorias
  using (puede_editar_menu(local_id)) with check (puede_editar_menu(local_id));

alter policy productos_write on productos
  using (puede_editar_menu(local_id)) with check (puede_editar_menu(local_id));

alter policy grupos_opciones_write on grupos_opciones
  using (exists (select 1 from productos p where p.id = grupos_opciones.producto_id and puede_editar_menu(p.local_id)))
  with check (exists (select 1 from productos p where p.id = grupos_opciones.producto_id and puede_editar_menu(p.local_id)));

alter policy opciones_write on opciones
  using (exists (
    select 1 from grupos_opciones g join productos p on p.id = g.producto_id
    where g.id = opciones.grupo_opcion_id and puede_editar_menu(p.local_id)
  ))
  with check (exists (
    select 1 from grupos_opciones g join productos p on p.id = g.producto_id
    where g.id = opciones.grupo_opcion_id and puede_editar_menu(p.local_id)
  ));

alter policy combos_write on combos
  using (puede_editar_menu(local_id)) with check (puede_editar_menu(local_id));

alter policy combo_items_write on combo_items
  using (exists (select 1 from combos c where c.id = combo_items.combo_id and puede_editar_menu(c.local_id)))
  with check (exists (select 1 from combos c where c.id = combo_items.combo_id and puede_editar_menu(c.local_id)));

alter policy promos_write on promos
  using (puede_editar_menu(local_id)) with check (puede_editar_menu(local_id));

alter policy promo_productos_write on promo_productos
  using (exists (select 1 from promos pr where pr.id = promo_productos.promo_id and puede_editar_menu(pr.local_id)))
  with check (exists (select 1 from promos pr where pr.id = promo_productos.promo_id and puede_editar_menu(pr.local_id)));

-- --- Storage de imágenes: solo las carpetas de menú (productos/combos)
-- pasan a puede_editar_menu. La carpeta "locales" (logo/banner de
-- Configuración) sigue dueño-only — el path es <carpeta>/<local_id>/..,
-- así que hay que mirar el primer segmento para no ampliar de más. ---

alter policy "imagenes escribe el dueno" on storage.objects
  with check (
    bucket_id = 'imagenes' and (
      ((storage.foldername(name))[1] in ('productos', 'combos') and puede_editar_menu(((storage.foldername(name))[2])::uuid))
      or
      ((storage.foldername(name))[1] not in ('productos', 'combos') and es_dueño_local(((storage.foldername(name))[2])::uuid))
    )
  );

alter policy "imagenes actualiza el dueno" on storage.objects
  using (
    bucket_id = 'imagenes' and (
      ((storage.foldername(name))[1] in ('productos', 'combos') and puede_editar_menu(((storage.foldername(name))[2])::uuid))
      or
      ((storage.foldername(name))[1] not in ('productos', 'combos') and es_dueño_local(((storage.foldername(name))[2])::uuid))
    )
  );

alter policy "imagenes borra el dueno" on storage.objects
  using (
    bucket_id = 'imagenes' and (
      ((storage.foldername(name))[1] in ('productos', 'combos') and puede_editar_menu(((storage.foldername(name))[2])::uuid))
      or
      ((storage.foldername(name))[1] not in ('productos', 'combos') and es_dueño_local(((storage.foldername(name))[2])::uuid))
    )
  );

-- --- listar_equipo_local: sumar las 2 columnas nuevas al listado ---
-- (drop porque cambia el shape de las OUT columns; create or replace solo
-- no lo permite)

drop function if exists listar_equipo_local(uuid);

create function listar_equipo_local(p_local_id uuid)
returns table (usuario_id uuid, email text, rol text, ve_facturacion boolean, edita_menu boolean, creado timestamptz)
language sql stable security definer set search_path = public as $$
  select ulr.usuario_id, u.email, ulr.rol, ulr.ve_facturacion, ulr.edita_menu, ulr.created_at
  from usuario_local_roles ulr
  join auth.users u on u.id = ulr.usuario_id
  where ulr.local_id = p_local_id and es_dueño_local(p_local_id)
  order by (ulr.rol = 'dueño') desc, ulr.created_at;
$$;

grant execute on function puede_ver_facturacion(uuid) to authenticated;
grant execute on function puede_editar_menu(uuid) to authenticated;
grant execute on function listar_equipo_local(uuid) to authenticated;
