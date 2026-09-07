-- Datos de prueba para validar el Hito 2a de punta a punta.
-- Pensado para correrse una sola vez (crea un negocio/local nuevo cada vez).
-- Todo en un único statement (CTEs encadenados): `supabase db query -f`
-- ejecuta el archivo como sentencia preparada y no acepta varios comandos
-- separados por ";".

with admin as (
  insert into super_admins (usuario_id)
  values ('cae55d9b-1f28-4ed6-a104-7f5c5045804e')
  on conflict (usuario_id) do nothing
  returning usuario_id
), nuevo_negocio as (
  insert into negocios (nombre, email_contacto)
  values ('Bar de Prueba', 'dueno@bardeprueba.test')
  returning id
), nuevo_local as (
  insert into locales (
    negocio_id, nombre, slug, estado,
    horario_apertura, horario_cierre, acepta_retiro, acepta_delivery
  )
  select id, 'Bar de Prueba', 'bar-de-prueba', 'activo',
    '18:00', '04:00', true, true
  from nuevo_negocio
  returning id
), rol_dueño as (
  -- el mismo usuario de prueba queda como dueño de este local, además de
  -- super-admin, para poder probar las dos vistas.
  insert into usuario_local_roles (usuario_id, local_id, rol)
  select 'cae55d9b-1f28-4ed6-a104-7f5c5045804e', id, 'dueño'
  from nuevo_local
), cat_tragos as (
  insert into categorias (local_id, nombre, orden)
  select id, 'Tragos', 1 from nuevo_local
  returning id
), cat_comida as (
  insert into categorias (local_id, nombre, orden)
  select id, 'Comida', 2 from nuevo_local
  returning id
), prod_fernet as (
  insert into productos (local_id, categoria_id, nombre, descripcion, precio, estacion, orden)
  select nuevo_local.id, cat_tragos.id, 'Fernet con Coca',
    'Fernet Branca + Coca Cola', 8000, 'barra', 1
  from nuevo_local, cat_tragos
  returning id
), prod_papas as (
  insert into productos (local_id, categoria_id, nombre, descripcion, precio, estacion, orden)
  select nuevo_local.id, cat_comida.id, 'Papas Fritas',
    'Bandeja de papas fritas', 6000, 'cocina', 1
  from nuevo_local, cat_comida
  returning id
), grupo_relleno as (
  insert into grupos_opciones (producto_id, nombre, obligatorio, orden)
  select id, 'Elegí el relleno', true, 1 from prod_papas
  returning id
)
insert into opciones (grupo_opcion_id, nombre, precio_ajuste, orden)
select id, 'Solas', 0, 1 from grupo_relleno
union all
select id, 'Con cheddar y bacon', 1500, 2 from grupo_relleno;

-- Un combo de prueba (agregado al probar el Hito 3 — carrito).
insert into combos (local_id, nombre, descripcion, precio, estacion)
select id, 'Combo Previa', 'Fernet con Coca + Papas Fritas', 12500, 'barra'
from locales where slug = 'bar-de-prueba';

-- Zonas de delivery de prueba (agregado al probar el Hito 4 — checkout).
insert into zonas_delivery (local_id, barrio, costo)
select id, 'Centro', 800 from locales where slug = 'bar-de-prueba'
union all
select id, 'Norte', 1200 from locales where slug = 'bar-de-prueba';

-- Config de pago/delivery de prueba (Hito 4). Mínimo en 10000 a propósito:
-- con productos de 6000-12500, un solo ítem no llega y dos sí — permite
-- probar el bloqueo por mínimo sin cargar un producto extra solo para eso.
update locales set
  alias_transferencia = 'bar.de.prueba.mp',
  delivery_costo_fijo = 900,
  delivery_minimo_compra = 10000
where slug = 'bar-de-prueba';
