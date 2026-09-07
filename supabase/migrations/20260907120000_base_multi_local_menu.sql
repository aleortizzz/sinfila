-- ============================================================
-- SinFila — Hito 2a: base multi-local + menú + RLS
-- Pegar y ejecutar en Supabase → SQL Editor (proyecto "sinfila")
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- 1) NEGOCIOS Y LOCALES
-- ============================================================

-- "negocio" = la empresa/dueño que contrata SinFila. Hoy siempre tiene un
-- solo local, pero separamos negocio de local desde el día uno para no
-- migrar nada si mañana un dueño abre una segunda sucursal.
create table negocios (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  email_contacto text,
  telefono_contacto text,
  created_at timestamptz not null default now()
);

-- La suscripción (mensualidad) es POR LOCAL, no por negocio — por eso
-- "estado" y "trial_hasta" viven acá y no en negocios.
create table locales (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid references negocios(id) on delete cascade not null,
  nombre text not null,

  -- URL pública: sinfila.tizdigital.com/<slug>. Solo minúsculas, números y
  -- guiones, sin barras — así no choca con las rutas propias de la app.
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),

  -- Ciclo de vida de la suscripción.
  --   pendiente_activacion → se registró el dueño, el super-admin no lo activó
  --   trial                → activado, período de prueba (30 días)
  --   activo                → pagando
  --   gracia                → venció, 5 días antes de cortar
  --   suspendido            → sin acceso, carta offline
  estado text not null default 'pendiente_activacion'
    check (estado in ('pendiente_activacion','trial','activo','gracia','suspendido')),
  trial_hasta date,

  -- Horario general del local. Null = no configurado todavía.
  horario_apertura time,
  horario_cierre time,
  -- Horario por estación: si quedan null, se usa el horario general.
  -- Cubre el caso "después de las 2am solo botellas, no tragos preparados"
  -- vía disponibilidad de categoría (Hito 2b/futuro), no acá.
  horario_barra_apertura time,
  horario_barra_cierre time,
  horario_cocina_apertura time,
  horario_cocina_cierre time,

  -- Branding del tier genérico de la carta.
  logo_url text,
  color_primario text,
  banner_url text,

  -- Cómo cobra este local.
  acepta_efectivo boolean not null default true,
  acepta_transferencia boolean not null default true,
  alias_transferencia text,
  cbu_transferencia text,

  -- Retiro y delivery.
  acepta_retiro boolean not null default true,
  acepta_delivery boolean not null default false,
  delivery_costo_modo text not null default 'fijo'
    check (delivery_costo_modo in ('fijo','por_barrio')),
  delivery_costo_fijo numeric(10,2) not null default 0,
  delivery_minimo_compra numeric(10,2) not null default 0,

  created_at timestamptz not null default now()
);

create index locales_negocio_id_idx on locales(negocio_id);

-- Barrios que reparte un local. Si delivery_costo_modo = 'fijo', el costo de
-- cada fila se ignora y se usa locales.delivery_costo_fijo; si es
-- 'por_barrio', se usa el costo de la fila correspondiente.
create table zonas_delivery (
  id uuid primary key default gen_random_uuid(),
  local_id uuid references locales(id) on delete cascade not null,
  barrio text not null,
  costo numeric(10,2) not null default 0,
  created_at timestamptz not null default now(),
  unique (local_id, barrio)
);

-- ============================================================
-- 2) USUARIOS Y ROLES
-- ============================================================

-- Super-admins de TizDigital (el usuario). No hereda de ninguna tabla de
-- negocio: es un flag global sobre auth.users.
create table super_admins (
  usuario_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Qué rol tiene cada usuario en cada local. Un mismo usuario podría
-- eventualmente tener roles en más de un local (ej. un dueño con 2 locales).
create table usuario_local_roles (
  usuario_id uuid references auth.users(id) on delete cascade not null,
  local_id uuid references locales(id) on delete cascade not null,
  rol text not null check (rol in ('dueño','staff')),
  created_at timestamptz not null default now(),
  primary key (usuario_id, local_id)
);

-- ============================================================
-- 3) MENÚ
-- ============================================================

create table categorias (
  id uuid primary key default gen_random_uuid(),
  local_id uuid references locales(id) on delete cascade not null,
  nombre text not null,
  orden int not null default 0,
  created_at timestamptz not null default now()
);

create index categorias_local_id_idx on categorias(local_id);

create table productos (
  id uuid primary key default gen_random_uuid(),
  local_id uuid references locales(id) on delete cascade not null,
  -- restrict: no se puede borrar una categoría mientras tenga productos
  -- (hay que reasignarlos primero). Evita productos huérfanos.
  categoria_id uuid references categorias(id) on delete restrict not null,
  nombre text not null,
  descripcion text,
  precio numeric(10,2) not null,
  foto_url text,
  estacion text not null check (estacion in ('barra','cocina')),
  disponible boolean not null default true,
  orden int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index productos_local_id_idx on productos(local_id);
create index productos_categoria_id_idx on productos(categoria_id);

-- "Armado": papas solas / con cheddar y bacon, pancho alemana / jyq, etc.
-- Elección única para el MVP (seleccion_multiple queda reservado a futuro).
create table grupos_opciones (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid references productos(id) on delete cascade not null,
  nombre text not null,
  obligatorio boolean not null default true,
  seleccion_multiple boolean not null default false,
  orden int not null default 0
);

create index grupos_opciones_producto_id_idx on grupos_opciones(producto_id);

create table opciones (
  id uuid primary key default gen_random_uuid(),
  grupo_opcion_id uuid references grupos_opciones(id) on delete cascade not null,
  nombre text not null,
  -- Ajuste sobre el precio del producto. 0 = no cambia el precio.
  precio_ajuste numeric(10,2) not null default 0,
  orden int not null default 0
);

create index opciones_grupo_opcion_id_idx on opciones(grupo_opcion_id);

-- Combo = bundle a precio fijo (ej. fernet + coca). Siempre disponible
-- (no tiene horario, a diferencia de las promos).
create table combos (
  id uuid primary key default gen_random_uuid(),
  local_id uuid references locales(id) on delete cascade not null,
  nombre text not null,
  descripcion text,
  precio numeric(10,2) not null,
  foto_url text,
  disponible boolean not null default true,
  orden int not null default 0,
  created_at timestamptz not null default now()
);

create index combos_local_id_idx on combos(local_id);

create table combo_items (
  id uuid primary key default gen_random_uuid(),
  combo_id uuid references combos(id) on delete cascade not null,
  -- restrict: si querés borrar un producto que integra un combo, primero
  -- hay que sacarlo del combo (para no romperlo en silencio).
  producto_id uuid references productos(id) on delete restrict not null,
  cantidad int not null default 1
);

create index combo_items_combo_id_idx on combo_items(combo_id);

-- Promos programadas: NxM (3x2) o precio especial, sobre un set explícito
-- de productos, en una franja horaria semanal (happy hour).
create table promos (
  id uuid primary key default gen_random_uuid(),
  local_id uuid references locales(id) on delete cascade not null,
  tipo text not null check (tipo in ('nxm','precio_especial')),
  nombre text not null,

  -- solo si tipo = 'nxm': "pagás m por cada n" (ej. 3x2 → n=3, m=2)
  n int,
  m int,
  -- solo si tipo = 'precio_especial'
  precio_especial numeric(10,2),

  -- 0 = domingo … 6 = sábado (coincide con extract(dow from timestamp))
  dias_semana int[] not null,
  hora_desde time not null,
  hora_hasta time not null,

  activa boolean not null default true,
  created_at timestamptz not null default now(),

  check (
    (tipo = 'nxm' and n is not null and m is not null and n > m)
    or
    (tipo = 'precio_especial' and precio_especial is not null)
  )
);

create index promos_local_id_idx on promos(local_id);

create table promo_productos (
  promo_id uuid references promos(id) on delete cascade not null,
  -- restrict: sacá el producto de la promo antes de borrarlo.
  producto_id uuid references productos(id) on delete restrict not null,
  primary key (promo_id, producto_id)
);

-- ============================================================
-- 4) FUNCIONES DE ACCESO (para RLS)
-- security definer: consultan tablas que también tienen RLS
-- (usuario_local_roles, super_admins); sin esto se pisarían con sus
-- propias políticas y podrían recursionar.
-- ============================================================

create or replace function es_super_admin()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from super_admins where usuario_id = auth.uid());
$$;

create or replace function rol_en_local(p_local_id uuid)
returns text
language sql stable security definer set search_path = public as $$
  select rol from usuario_local_roles
  where local_id = p_local_id and usuario_id = auth.uid()
  limit 1;
$$;

-- Dueño o staff del local, o super-admin.
create or replace function tiene_acceso_local(p_local_id uuid)
returns boolean
language sql stable as $$
  select rol_en_local(p_local_id) is not null or es_super_admin();
$$;

-- Solo dueño del local (o super-admin).
create or replace function es_dueño_local(p_local_id uuid)
returns boolean
language sql stable as $$
  select rol_en_local(p_local_id) = 'dueño' or es_super_admin();
$$;

-- El local se puede ver desde la carta pública (no está suspendido).
create or replace function local_visible_publicamente(p_local_id uuid)
returns boolean
language sql stable as $$
  select estado in ('trial','activo','gracia')
  from locales where id = p_local_id;
$$;

-- ============================================================
-- 5) ROW LEVEL SECURITY
-- ============================================================

alter table negocios enable row level security;
alter table locales enable row level security;
alter table zonas_delivery enable row level security;
alter table super_admins enable row level security;
alter table usuario_local_roles enable row level security;
alter table categorias enable row level security;
alter table productos enable row level security;
alter table grupos_opciones enable row level security;
alter table opciones enable row level security;
alter table combos enable row level security;
alter table combo_items enable row level security;
alter table promos enable row level security;
alter table promo_productos enable row level security;

-- negocios: lo ve el super-admin, o quien tenga acceso a algún local de ese
-- negocio (el dueño necesita ver el nombre de su empresa).
create policy negocios_select on negocios for select
  using (
    es_super_admin()
    or exists (
      select 1 from locales l
      where l.negocio_id = negocios.id and tiene_acceso_local(l.id)
    )
  );
-- Alta de negocio: por ahora solo el super-admin (a mano, para probar). El
-- alta autogestionable por el dueño se resuelve con una función dedicada
-- cuando hagamos el Hito de registro/onboarding.
create policy negocios_insert on negocios for insert
  with check (es_super_admin());
create policy negocios_update on negocios for update
  using (es_super_admin());
create policy negocios_delete on negocios for delete
  using (es_super_admin());

-- locales: visible públicamente si no está suspendido, o si tenés acceso
-- (así el dueño/staff de un local suspendido igual puede entrar a ver el
-- aviso de "pagá para reanudar").
create policy locales_select on locales for select
  using (estado in ('trial','activo','gracia') or tiene_acceso_local(id));
create policy locales_insert on locales for insert
  with check (es_super_admin());
-- El dueño puede actualizar su local (columnas de config — ver los GRANT
-- más abajo, que le sacan permiso de tocar estado/trial_hasta).
create policy locales_update on locales for update
  using (es_dueño_local(id));
create policy locales_delete on locales for delete
  using (es_super_admin());

-- El dueño puede editar la config de su local, pero NO su propia
-- suscripción (estado, trial_hasta) — eso lo toca el super-admin o, más
-- adelante, un webhook/función de cobro. Postgres permite dar permiso de
-- UPDATE columna por columna.
revoke update on locales from authenticated;
grant update (
  nombre, horario_apertura, horario_cierre,
  horario_barra_apertura, horario_barra_cierre,
  horario_cocina_apertura, horario_cocina_cierre,
  logo_url, color_primario, banner_url,
  acepta_efectivo, acepta_transferencia, alias_transferencia, cbu_transferencia,
  acepta_retiro, acepta_delivery, delivery_costo_modo,
  delivery_costo_fijo, delivery_minimo_compra
) on locales to authenticated;

create policy zonas_delivery_select on zonas_delivery for select
  using (local_visible_publicamente(local_id) or tiene_acceso_local(local_id));
create policy zonas_delivery_write on zonas_delivery for all
  using (es_dueño_local(local_id)) with check (es_dueño_local(local_id));

create policy super_admins_select on super_admins for select
  using (es_super_admin());
-- Sin policy de insert/update/delete: el primer super-admin se carga a mano
-- desde el SQL Editor (con el rol postgres, que no pasa por RLS).

create policy usuario_local_roles_select on usuario_local_roles for select
  using (usuario_id = auth.uid() or es_dueño_local(local_id) or es_super_admin());
create policy usuario_local_roles_write on usuario_local_roles for all
  using (es_dueño_local(local_id)) with check (es_dueño_local(local_id));

create policy categorias_select on categorias for select
  using (local_visible_publicamente(local_id) or tiene_acceso_local(local_id));
create policy categorias_write on categorias for all
  using (es_dueño_local(local_id)) with check (es_dueño_local(local_id));

create policy productos_select on productos for select
  using (local_visible_publicamente(local_id) or tiene_acceso_local(local_id));
create policy productos_write on productos for all
  using (es_dueño_local(local_id)) with check (es_dueño_local(local_id));

create policy grupos_opciones_select on grupos_opciones for select
  using (exists (
    select 1 from productos p where p.id = producto_id
    and (local_visible_publicamente(p.local_id) or tiene_acceso_local(p.local_id))
  ));
create policy grupos_opciones_write on grupos_opciones for all
  using (exists (
    select 1 from productos p where p.id = producto_id and es_dueño_local(p.local_id)
  ))
  with check (exists (
    select 1 from productos p where p.id = producto_id and es_dueño_local(p.local_id)
  ));

create policy opciones_select on opciones for select
  using (exists (
    select 1 from grupos_opciones g
    join productos p on p.id = g.producto_id
    where g.id = grupo_opcion_id
    and (local_visible_publicamente(p.local_id) or tiene_acceso_local(p.local_id))
  ));
create policy opciones_write on opciones for all
  using (exists (
    select 1 from grupos_opciones g
    join productos p on p.id = g.producto_id
    where g.id = grupo_opcion_id and es_dueño_local(p.local_id)
  ))
  with check (exists (
    select 1 from grupos_opciones g
    join productos p on p.id = g.producto_id
    where g.id = grupo_opcion_id and es_dueño_local(p.local_id)
  ));

create policy combos_select on combos for select
  using (local_visible_publicamente(local_id) or tiene_acceso_local(local_id));
create policy combos_write on combos for all
  using (es_dueño_local(local_id)) with check (es_dueño_local(local_id));

create policy combo_items_select on combo_items for select
  using (exists (
    select 1 from combos c where c.id = combo_id
    and (local_visible_publicamente(c.local_id) or tiene_acceso_local(c.local_id))
  ));
create policy combo_items_write on combo_items for all
  using (exists (select 1 from combos c where c.id = combo_id and es_dueño_local(c.local_id)))
  with check (exists (select 1 from combos c where c.id = combo_id and es_dueño_local(c.local_id)));

create policy promos_select on promos for select
  using (local_visible_publicamente(local_id) or tiene_acceso_local(local_id));
create policy promos_write on promos for all
  using (es_dueño_local(local_id)) with check (es_dueño_local(local_id));

create policy promo_productos_select on promo_productos for select
  using (exists (
    select 1 from promos pr where pr.id = promo_id
    and (local_visible_publicamente(pr.local_id) or tiene_acceso_local(pr.local_id))
  ));
create policy promo_productos_write on promo_productos for all
  using (exists (select 1 from promos pr where pr.id = promo_id and es_dueño_local(pr.local_id)))
  with check (exists (select 1 from promos pr where pr.id = promo_id and es_dueño_local(pr.local_id)));
