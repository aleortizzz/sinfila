-- ============================================================
-- SinFila — Hito 2b: pedidos, ítems, estado por estación, delivery
-- ============================================================

-- Retoque a 2a: para el MVP asumimos que un combo se prepara/entrega desde
-- UNA sola estación (simplifica el KDS). Si algún combo real cruza barra y
-- cocina, se decide en fase 2 (descomponerlo en ítems por separado).
alter table combos add column estacion text not null default 'barra'
  check (estacion in ('barra','cocina'));
alter table combos alter column estacion drop default;

-- ============================================================
-- 1) NUMERACIÓN DIARIA POR LOCAL
-- Tabla interna (sin acceso por API) + función + trigger. El upsert con
-- ON CONFLICT es atómico: dos pedidos simultáneos nunca chocan de número.
-- ============================================================

create table pedidos_contador (
  local_id uuid references locales(id) on delete cascade not null,
  fecha date not null,
  ultimo_numero int not null default 0,
  primary key (local_id, fecha)
);

create or replace function asignar_numero_pedido()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_fecha date := (now() at time zone 'America/Argentina/Buenos_Aires')::date;
  v_numero int;
begin
  insert into pedidos_contador (local_id, fecha, ultimo_numero)
  values (new.local_id, v_fecha, 1)
  on conflict (local_id, fecha)
    do update set ultimo_numero = pedidos_contador.ultimo_numero + 1
  returning ultimo_numero into v_numero;

  new.numero := v_numero;
  return new;
end;
$$;

-- ============================================================
-- 2) PEDIDOS
-- ============================================================

create table pedidos (
  id uuid primary key default gen_random_uuid(),
  -- restrict: no se borra un local con historial de pedidos.
  local_id uuid references locales(id) on delete restrict not null,
  -- lo pone el trigger asignar_numero_pedido(), nunca lo manda la app.
  numero int not null,

  tipo_entrega text not null check (tipo_entrega in ('retiro','delivery')),
  metodo_pago text not null check (metodo_pago in ('efectivo','transferencia')),
  -- el cliente tocó "ya transferí" (solo aplica si metodo_pago = transferencia)
  transferencia_avisada boolean not null default false,

  -- pendiente: recién creado, el cliente todavía puede cancelar.
  -- en_preparacion: el local lo aceptó (ya no se puede cancelar).
  -- listo: listo para retirar / para salir a delivery.
  -- entregado / cancelado / rechazado: estados finales.
  estado text not null default 'pendiente'
    check (estado in ('pendiente','en_preparacion','listo','entregado','cancelado','rechazado')),

  -- Progreso por estación (KDS): si el pedido tiene ítems de barra Y cocina,
  -- pasa a "listo" recién cuando las dos terminaron. Ver trigger más abajo.
  requiere_barra boolean not null default false,
  requiere_cocina boolean not null default false,
  barra_lista boolean not null default false,
  cocina_lista boolean not null default false,

  nombre_cliente text not null,
  telefono_cliente text not null,

  -- Solo si tipo_entrega = 'delivery'. El link de Maps se arma en el
  -- frontend (encodeURIComponent de la dirección) y se guarda tal cual.
  direccion_calle text,
  direccion_numero text,
  direccion_piso_depto text,
  direccion_barrio text,
  direccion_referencia text,
  direccion_maps_url text,

  -- Snapshots de plata: no se recalculan si después cambian precios o config.
  costo_delivery numeric(10,2) not null default 0,
  subtotal numeric(10,2) not null default 0,        -- lo mantiene el trigger de abajo
  descuento_promos numeric(10,2) not null default 0, -- ídem
  total numeric(10,2) not null default 0,            -- ídem

  created_at timestamptz not null default now()
);

create trigger trg_asignar_numero_pedido
  before insert on pedidos
  for each row execute function asignar_numero_pedido();

create index pedidos_local_id_idx on pedidos(local_id);
create index pedidos_local_id_estado_idx on pedidos(local_id, estado);

-- Red de seguridad extra sobre la numeración: nunca puede haber dos pedidos
-- con el mismo número el mismo día en el mismo local.
create unique index pedidos_numero_por_dia_idx
  on pedidos (local_id, numero, ((created_at at time zone 'America/Argentina/Buenos_Aires')::date));

-- Cuando cambian barra_lista/cocina_lista, si ya no falta ninguna estación
-- requerida, promovemos el pedido a "listo" automáticamente.
create or replace function promover_estado_si_listo()
returns trigger
language plpgsql as $$
begin
  if new.estado = 'en_preparacion'
     and (not new.requiere_barra or new.barra_lista)
     and (not new.requiere_cocina or new.cocina_lista) then
    new.estado := 'listo';
  end if;
  return new;
end;
$$;

create trigger trg_promover_estado_si_listo
  before update of barra_lista, cocina_lista on pedidos
  for each row execute function promover_estado_si_listo();

-- ============================================================
-- 3) HISTORIAL DE ESTADOS (auditoría)
-- ============================================================

create table pedido_estados (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid references pedidos(id) on delete cascade not null,
  estado text not null,
  changed_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index pedido_estados_pedido_id_idx on pedido_estados(pedido_id);

create or replace function registrar_estado_inicial()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into pedido_estados (pedido_id, estado, changed_by) values (new.id, new.estado, auth.uid());
  return new;
end;
$$;

create or replace function registrar_cambio_estado()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.estado is distinct from old.estado then
    insert into pedido_estados (pedido_id, estado, changed_by) values (new.id, new.estado, auth.uid());
  end if;
  return new;
end;
$$;

create trigger trg_pedido_estado_inicial
  after insert on pedidos
  for each row execute function registrar_estado_inicial();

create trigger trg_pedido_estado_cambio
  after update of estado on pedidos
  for each row execute function registrar_cambio_estado();

-- ============================================================
-- 4) ÍTEMS DEL PEDIDO
-- ============================================================

create table pedido_items (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid references pedidos(id) on delete cascade not null,

  tipo text not null check (tipo in ('producto','combo')),
  producto_id uuid references productos(id) on delete set null,
  combo_id uuid references combos(id) on delete set null,

  -- Snapshot al momento del pedido: sobrevive aunque el producto/combo
  -- cambie de precio o se borre después.
  nombre text not null,
  precio_unitario numeric(10,2) not null,
  cantidad int not null default 1 check (cantidad > 0),
  estacion text not null check (estacion in ('barra','cocina')),

  -- Armado elegido (papas solas/con cheddar, etc), snapshot también:
  -- [{ "grupo": "Elegí el relleno", "opcion": "Con cheddar y bacon", "precio_ajuste": 1500 }]
  opciones_elegidas jsonb not null default '[]'::jsonb,

  promo_id uuid references promos(id) on delete set null,
  descuento_aplicado numeric(10,2) not null default 0,

  created_at timestamptz not null default now(),

  check (
    (tipo = 'producto' and producto_id is not null and combo_id is null)
    or
    (tipo = 'combo' and combo_id is not null and producto_id is null)
  )
);

create index pedido_items_pedido_id_idx on pedido_items(pedido_id);

-- Ni subtotal, ni descuento, ni total se aceptan "de confianza" desde el
-- cliente: se recalculan siempre acá, a partir de los ítems reales.
create or replace function recalcular_totales_pedido()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_pedido_id uuid := coalesce(new.pedido_id, old.pedido_id);
  v_subtotal numeric(10,2);
  v_descuento numeric(10,2);
begin
  select coalesce(sum(precio_unitario * cantidad), 0),
         coalesce(sum(descuento_aplicado * cantidad), 0)
    into v_subtotal, v_descuento
    from pedido_items
    where pedido_id = v_pedido_id;

  update pedidos
    set subtotal = v_subtotal,
        descuento_promos = v_descuento,
        total = v_subtotal - v_descuento + costo_delivery
    where id = v_pedido_id;

  return null;
end;
$$;

create trigger trg_recalcular_totales
  after insert or update or delete on pedido_items
  for each row execute function recalcular_totales_pedido();

-- Cada ítem "avisa" a su pedido qué estación necesita (se acumula con OR;
-- nunca se desmarca, ni siquiera si después se borra ese ítem — un pedido
-- que alguna vez tuvo algo de cocina sigue necesitando el visto bueno de
-- cocina, para no complicarnos con casos raros de edición del carrito).
create or replace function marcar_estacion_requerida()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update pedidos set
    requiere_barra = requiere_barra or (new.estacion = 'barra'),
    requiere_cocina = requiere_cocina or (new.estacion = 'cocina')
  where id = new.pedido_id;
  return new;
end;
$$;

create trigger trg_marcar_estacion_requerida
  after insert on pedido_items
  for each row execute function marcar_estacion_requerida();

-- ============================================================
-- 5) ROW LEVEL SECURITY
-- ============================================================

alter table pedidos_contador enable row level security;
alter table pedidos enable row level security;
alter table pedido_estados enable row level security;
alter table pedido_items enable row level security;

-- pedidos_contador: tabla 100% interna. Sin policies = nadie la toca por
-- API; el trigger sí puede escribir porque es security definer.

-- pedidos: cualquiera puede crear un pedido en un local visible (así pide
-- un cliente sin cuenta). Leer y actualizar (aceptar/marcar listo/etc.)
-- es solo para quien tiene acceso al local (dueño o staff).
create policy pedidos_select on pedidos for select
  using (tiene_acceso_local(local_id));
create policy pedidos_insert on pedidos for insert
  with check (local_visible_publicamente(local_id));
create policy pedidos_update on pedidos for update
  using (tiene_acceso_local(local_id));
-- Sin policy de delete: los pedidos no se borran por API (quedan de
-- auditoría/estadísticas). El seguimiento del cliente sin login
-- ("¿cómo va mi pedido?") y la cancelación se resuelven con una función
-- propia (security definer, valida el estado antes de dejar cancelar) en
-- el Hito de checkout/seguimiento — exponer SELECT/UPDATE directo a "quien
-- tenga el id" dejaría listar pedidos ajenos.

create policy pedido_items_select on pedido_items for select
  using (exists (
    select 1 from pedidos p where p.id = pedido_id and tiene_acceso_local(p.local_id)
  ));
create policy pedido_items_insert on pedido_items for insert
  with check (exists (
    select 1 from pedidos p where p.id = pedido_id and local_visible_publicamente(p.local_id)
  ));
create policy pedido_items_update on pedido_items for update
  using (exists (
    select 1 from pedidos p where p.id = pedido_id and tiene_acceso_local(p.local_id)
  ));

create policy pedido_estados_select on pedido_estados for select
  using (exists (
    select 1 from pedidos p where p.id = pedido_id and tiene_acceso_local(p.local_id)
  ));
-- Sin insert/update/delete: pedido_estados solo lo escriben los triggers.
