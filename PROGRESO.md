# Kiosko — seguimiento del proyecto

**Producto SaaS multi-local** (no una app para un solo local). Idea: "no hagas
fila, escaneá y esperá tu pedido". El cliente de un local arma el pedido desde el
celu (QR), paga y elige retiro o delivery. La pantalla del local ve los pedidos
nuevos en tiempo real. El usuario le vende el servicio a muchos locales.

Modo de trabajo: **aprender haciendo** — explicar el porqué de cada decisión, ir
hito por hito, probar cada cosa antes de seguir. No armar toda la app de una.
El usuario viene fuerte de HTML/CSS/Tailwind, aprendiendo JS/Vue.

## Decisiones firmes

- **Multi-tenant**: una sola base Postgres compartida, columna `negocio_id` en
  todas las tablas + RLS que aísla cada local. NO un proyecto de Supabase por
  local.
- **Modelo de cobro**: mensualidad por local (sin comisión por venta por ahora;
  queda como opción futura). Cobro manual al principio (marcar `activo` a mano).
  Débito automático con MP → fase futura.
- **Dominio**: ruta por local bajo un subdominio único de TizDigital →
  `NOMBRE-APP.tizdigital.com/nombre-local`. Sin wildcard, sin dominios propios
  por local nunca.
- **Supabase**: organización nueva (misma cuenta), plan Free para construir y
  pilotear. Pro cuando haya locales pagando.
- Cada local cobra en **su propia cuenta de Mercado Pago** (credenciales por
  local vía OAuth).
- Tres roles: super-admin (el usuario), dueño del local, staff (pantalla KDS).

## Discovery — definiciones del producto (2026-09-07)

Producto de **TizDigital**, todavía sin nombre propio (define el subdominio).

**Rubro / alcance**
- Kiosko que vende tragos + combos (fernet+coca) + comida (milanesas, papas,
  panchos). Diseñar el menú para ese caso; no hace falta que sea ultra genérico.
- Negocios de **un solo local**. Igual dejar el modelo preparado para
  multi-sucursal (negocio → locales), creando 1 local por negocio en el MVP.

**Operación del local (referencia del flujo actual)**
- Atención a la calle: una persona toma el pedido en un papelito numerado tipo
  sorteo, le da el número al cliente y lleva el pedido a mano a la cocina.
- Config por local: pedidos llegan **todos juntos** o **separados por estación**
  (barra / cocina). Modelar "estaciones"; cada producto pertenece a una; el KDS
  muestra todo o filtra por estación.
- Horarios configurables: apertura/cierre general del local + por estación
  (barra / cocina) por separado.
- Regla tipo "después de las 02:00 solo alcohol en botella, no tragos
  preparados" → disponibilidad de **categoría por franja horaria**.

**Menú y productos**
- Sin variantes tipo talle/término. SÍ "armado": papas (solas / cheddar+bacon),
  panchos (alemana / jyq / cheddar…) → **grupos de opciones** de elección única.
  (Pendiente: ¿cambian el precio o no?)
- Sin adicionales con costo suelto (venden por bandeja: papas chica/grande son
  productos distintos).
- **Combos/promos**: muy usados y cambian por día. Ej: domingo 3x2 en tragos de
  $8000 hasta las 00:00. Combo fijo (fernet+coca) = producto. Promos NxM /
  happy hour / % por franja = motor de promos (probablemente fase 2).
- **Precio por categoría**: los tragos se agrupan por precio ("tragos $8000" =
  15 productos; "tragos con gomitas $12000" = 10). La suba es por categoría:
  todos los de $8000 pasan a $9000. Modelo: producto hereda precio de su
  categoría salvo override propio. Acción "subir precio" (nuevo valor o +%).
- Stock: toggle disponible/agotado a mano (lo más usado) **y** opción de
  cantidad real que descuenta. Las dos.
- Todo producto: foto, título, descripción, precio, orden. Foto no obligatoria
  pero esperada.

**Pedidos**
- Sin registro del cliente. Nombre + teléfono **obligatorios** para pedir.
- Al cerrar el pedido, el cliente recibe un **número**. La comanda muestra
  número de pedido + nombre.
- Solo "lo antes posible" (sin agendar) para el MVP.
- Cancelación: el cliente puede cancelar **mientras el local no lo aceptó**.
  Una vez aceptado (en preparación) ya no. El local puede rechazar/cancelar.
- Sin propina.
- Estados: `recibido → en preparación → listo para retirar → entregado`
  (+ `pendiente`, `cancelado`, `rechazado`; + estado de envío para delivery).
- **Gate de aceptación**: el pedido entra como pendiente; el local
  Acepta/Rechaza. Ese gate cubre también "evitar clientes fantasma" en efectivo
  (configurable por local: exigir confirmación o no).

**Pagos**
- Mercado Pago, transferencia, efectivo.
- Transferencia (MVP): mostrar alias + botón "Ya transferí"; el local mira su
  homebanking y acepta. Sin subir comprobante en el MVP.
- Efectivo: el local configura si exige confirmación antes de preparar.
- **Sin factura AFIP ni ticket** — la comanda en pantalla alcanza.
- MP: OAuth por local + webhook por local vía Edge Function. (¿MVP o fase 2?)

**Delivery / retiro**
- Cadetes propios, sin integraciones (Rappi/PedidosYa/Cabify).
- Zona de reparto = **lista de barrios** que sirve el local.
- Costo de envío: configurable por local — modos fijo / por zona / por
  distancia. Mínimo de compra para delivery, configurable por local.
- Dirección: campos detallados (calle, número, piso/depto, barrio, referencia)
  + link autogenerado a Google Maps. Sin mapa interactivo en el MVP.

**Pantalla del local (KDS)**
- Responsive de verdad: PC, celular, tablet, tótem.
- Sin impresión térmica; se manejan mirando la pantalla.
- **Alerta sonora** al entrar un pedido.
- "Listo para retirar" → aviso al cliente + vista resumen de la comanda para la
  persona de mostrador (ítems + nombre del cliente).

**Usuarios y alta de locales**
- Alta **autogestionable** (wizard de onboarding). El usuario igual acompaña.
- **30 días** de prueba gratis.
- Falta de pago: **5 días de gracia** tras el vencimiento (para contactar al
  local). Después → suspensión (definir exactamente qué se corta).
- Roles: **dueño** (config + estadísticas/reportes) y **staff** (KDS). Gestión
  de roles.

**Front de la carta (cliente final)**
- Solo español.
- Dos tiers: **genérico** (logo + color) y **100% personalizado** (otro precio,
  fase futura). El renderizado de la carta debe poder tematizarse por local.
- **PWA instalable** desde el arranque.

**MVP**
- Sin cerrar. El usuario quiere tener el producto funcionando bien para salir a
  ofrecerlo; no hay ningún local comprometido todavía. → Definir scope de MVP
  desde nuestro lado y que el usuario lo apruebe.

## Discovery — segunda ronda (2026-09-07)

- **Nombre del producto: SinFila.** Subdominio: `sinfila.tizdigital.com/<local>`.
  Supabase: organización `TizDigital`, proyecto `sinfila`.
- **Grupos de opciones** (armado papas/panchos): elección única. Cada opción
  puede llevar un **ajuste de precio** (delta +$, puede ser 0). El local decide
  si lo carga como opciones o como productos separados.
- **Precios**: cada producto tiene su precio propio (sin herencia de categoría).
  Herramienta de **edición masiva**: seleccionar varios productos de una
  categoría y fijarles un precio, o aplicar +X%. Los demás se editan 1x1.
- Un producto pertenece a **una sola categoría**.
- **Estaciones**: fijas, `barra` y `cocina`. Cada producto se cataloga en una.
  KDS: vista por estación + vista "todos" para juntar el pedido.
- **Mercado Pago: NO en el MVP.** Solo efectivo + transferencia.
- **Promos: SÍ en el MVP.**
  - Combos: bundle a precio fijo (producto).
  - Promos programadas: por categoría, con **horario semanal** (días + franja
    horaria). Ej: "viernes 17–21h, 3x2 en tragos de $8000".
- **Aviso "pedido listo"**: web push + página en vivo (free). Además, botón en
  el KDS "Avisar por WhatsApp" → abre `wa.me/<tel del cliente>` con mensaje
  prearmado (lo manda el staff desde su propio WhatsApp, gratis).
- **Suspensión por falta de pago**: avisos escalonados durante la gracia ("se
  da de baja en 3 días…"). Al suspender: el dueño ve una página "pagá para
  reanudar el servicio"; la carta del cliente queda offline; los pedidos en
  curso se terminan.
- **Checkout**: solo nombre + teléfono (sin email).
- **Branding tier genérico**: logo + color + banner tipo hero.
- **Trial**: el dueño se registra → estado "a la espera de activación". El
  super-admin (usuario) lo activa → recién ahí entra y arrancan los 30 días.

## Discovery — tercera ronda (2026-09-07)

- **Gate de aceptación para TODOS los pedidos**: cualquier pedido (efectivo,
  transferencia, lo que sea) entra como `pendiente`; el staff toca "Iniciar" →
  recién ahí el cliente ve "en preparación". → El toggle "exigir confirmación
  en efectivo" **se elimina del MVP**: el gate único ya cubre el cliente
  fantasma para todos los métodos.
- **Delivery MVP**: costo fijo + por barrio. Por distancia → fase 2.
- **Disponibilidad de productos (agotado / corte nocturno de tragos)**: campo
  `disponible` manual **por producto**. Pantalla de gestión con filtro por
  categoría + "seleccionar todos" + activar/desactivar en masa. Ventanas
  horarias automáticas (corte 02:00 auto) → fase 2.
- **Zona horaria**: fija, `America/Argentina/Buenos_Aires`, para todos los
  horarios del sistema.
- **Fórmula NxM** (pagás M por cada N): `gratis = floor(cant/N) * (N-M)`,
  `a_pagar = cant - gratis`. Unidades gratis = las más baratas de la categoría.
- **Ritmo**: el usuario está cómodo con MVP completo, varios meses hito por hito.

## Discovery — cuarta ronda (2026-09-07) — MVP CERRADO

- **Tipos de promo (MVP)**: `combo` (bundle a precio fijo), `nxm` (3x2 etc.),
  `precio_especial` sobre un set de productos en una franja horaria semanal
  (happy hour; el % de descuento sale con el mismo motor).
- **Alcance de una promo = set explícito de productos** (no "toda la categoría"
  como concepto rígido). La UI para armar el set es un **filtro + multiselección**:
  elegir tipo → "seleccionar ítems" → filtrar por categoría / precio (ej.
  precio = $8000) → "seleccionar todos" → aplicar → destildar los que no entren.
  Mismo patrón que el editor de precios en masa y el gestor de disponibilidad.
- **Apilado de promos**: un producto puede estar en varias, pero al calcular el
  carrito aplica **una sola** — la que más le conviene al cliente. Sin apilar.
- **KDS opción (b)**: cada estación (barra / cocina) marca su parte como lista;
  el pedido pasa a "listo para retirar" cuando **todas** las estaciones
  involucradas terminaron. La vista de mostrador muestra el progreso por
  estación.
- **Número de pedido**: correlativo por local, se reinicia cada día.

## Diseño — dos frentes separados

- **Carta del cliente**: liviana, mobile-first (se abre desde el QR).
- **Panel admin** (dueño/staff cargan productos, config del local, ven
  pedidos/estadísticas): dashboard SaaS aparte, estilo oscuro con tarjetas de
  métricas, tablas y filtros (referencia visual: dashboards tipo
  Salesforce/Stripe — tarjetas de stats arriba, tabla filtrable abajo). Falta
  definir el nombre de esta sección dentro del producto.

## Estado actual — Pasada de diseño visual (2026-09-08)

Primera pasada fuerte de UI sobre todo lo ya construido (a pedido del
usuario: "que las cosas tengan un orden visual para ir viendo el
progreso"). Solo markup/estilo, sin tocar lógica.

- **Sistema de diseño** en `src/style.css` (Tailwind v4, CSS-first):
  tokens `@theme` — fuente **Plus Jakarta Sans** (cargada en `index.html`),
  escala de color `brand-*` (rojo "apetito" `#f5401f`) y `sand-*` (neutro
  cálido para el fondo de la carta). Clases de componente reutilizables:
  `.btn` + `.btn-brand/.btn-dark/.btn-ghost`, `.input`, `.card`, `.label`,
  `.chip` + `.chip-active`, `.add-btn`, `.t-brand`.
- **Tono por local**: `--brand` se puede pisar con `local.color_primario`
  vía `:style` en el wrapper de la carta/checkout/seguimiento; las clases
  de componente leen `var(--brand)`, las utilidades `brand-*` son el
  fallback fijo.
- **Carta** (`Carta.vue` + `ProductoCard`/`ComboCard`/`CarritoResumen`):
  hero con banner (`banner_url` o gradiente de marca) + logo + nombre,
  **nav de categorías pegajosa** con scroll-spy (IntersectionObserver),
  grilla de tarjetas con foto (o placeholder), chips de opciones, precio y
  botón "+" circular con feedback ✓. Combos con badge y "Ahorrás $X".
  Carrito = barra flotante colapsable (pill con total → panel con detalle
  y CTA al pago).
- **Checkout / Seguimiento**: secciones en `.card`, inputs y chips
  unificados, tracker de progreso con línea de avance, pantalla de
  confirmación con ícono.
- **Admin**: `AdminLayout` con sidebar (logo, "Ver carta", logout abajo) y
  contenedor `max-w-5xl`; `AdminHome` = dashboard con tarjetas de stats
  (placeholders "Pronto") + accesos rápidos. `AdminMenu`/`AdminPromos`:
  acento `indigo` → `brand` para unificar (lógica intacta).
- **KDS / Login / Home**: repintados con el mismo sistema.
- **Formato de moneda**: `src/lib/formato.js` → `pesos()` (`$12.000`),
  aplicado en las tarjetas y el carrito. Pendiente: extenderlo a checkout,
  seguimiento y admin.
- `npm run build` OK. Probado en el navegador (headless) a 1280 / 768 px.

Pendiente de diseño (anotado, para próximas pasadas): fotos reales de
productos, formato de moneda en el resto de las pantallas, y que el dueño
edite branding (logo/color/banner) desde el admin — eso va con "Config del
local" (Hito 8b).

## Estado actual — Preview de promo en el checkout (2026-09-08)

Cierra el pendiente del Hito 9b ("ver el descuento antes de pagar").

- Migración `20260908130000_previsualizar_pedido.sql`: función
  `previsualizar_pedido(payload)` — corre el MISMO cálculo que
  `crear_pedido` (precio real + opciones + `calcular_descuentos_promo` del
  Hito 9a) pero **sin insertar**. Devuelve
  `{ subtotal, descuento_promos, total, items }`. `security definer`,
  grant a `anon`/`authenticated`. Sin duplicar lógica en JS → el número que
  muestra el checkout es exactamente el que se cobra.
- `Checkout.vue`: llama a la función al entrar y al tocar el carrito
  (debounce 250 ms). Muestra línea "Descuento (promo)" y usa el total con
  descuento. Si la función falla (no desplegada / red), cae al subtotal
  sin promo sin romper. Formato `pesos()` en todos los importes.
- Bug de paso: `obtenerPedidosActivos` no incluía `avisado`, así que los
  pedidos esperando retiro desaparecían del KDS al recargar. Corregido.
- **Pendiente**: aplicar la migración (`supabase db push`) y probar con las
  promos cargadas. Pendiente aparte: mostrar el descuento también en el
  carrito de la carta (misma llamada, no está cableado ahí todavía).

## Estado actual — Hito 8b: Config del local en progreso (2026-09-08)

Pantalla de configuración del local (`/panel/:slug/admin/config`, nuevo
ítem "Configuración" en el sidebar). **Sin migración**: el esquema base ya
tiene los GRANT columna por columna para el dueño y la policy de
`zonas_delivery`.

- `lib/admin.js`: `actualizarLocal()` + CRUD de `zonas_delivery`
  (`obtenerZonasAdmin`/`crearZona`/`actualizarZona`/`eliminarZona`).
- `lib/locales.js`: `obtenerLocalPorSlug` ahora trae también las 6 columnas
  de horario (las necesita la pantalla de config; la carta las puede usar
  más adelante para "abierto/cerrado").
- `AdminConfig.vue`: un `form` sembrado del `local`, con secciones Datos /
  Horarios (general + barra + cocina, vacío hereda el general) / Imagen de
  la carta (logo, banner, color principal con color-picker — alimentan el
  rediseño visual) / Pago (switches + alias/CBU) / Entrega (switches, modo
  fijo vs por_barrio, costo, mínimo, y lista de zonas con CRUD inmediato +
  ajuste en masa `+/- N%` sobre el costo de todas las zonas — mismo patrón
  que va a tener el editor de precios de productos).
  Barra fija abajo con "Guardar cambios". Al guardar hace `Object.assign`
  sobre el `local` compartido, así el sidebar y la carta reflejan el
  cambio sin recargar. Errores de permiso de columna se traducen.
- `AdminHome.vue`: la tarjeta "Configuración del local" ahora enlaza.
- `npm run build` OK. **Falta probar logueado como dueño en el navegador.**

## Estado actual — Horarios por día + carta abierto/cerrado (2026-09-08)

Migración `20260908140000_horarios_local.sql`:
- Tabla `horarios_local` (7 filas por local: `dia` 0-6, `abierto`, `apertura`,
  `cierre`). Cruzar medianoche = cierre <= apertura. RLS: público lee,
  dueño escribe. Backfill de los locales existentes desde
  `locales.horario_*` (esas columnas quedan, sin uso por ahora).
- `local_abierto(local_id)` — bool, hora de Argentina, contempla el tramo
  de hoy y la cola de ayer. Sin filas → true (no bloquear por dato faltante).
- Trigger `before insert on pedidos` que rechaza el pedido si el local está
  cerrado (cubre cualquier camino, no solo el RPC).
- `AdminConfig`: la sección Horarios pasó a editor de 7 días (switch
  abierto/cerrado + rango por día, guardado inmediato). Se sacaron los
  campos General/Barra/Cocina de la UI.
- `Carta`: pill "Abierto ahora / Cerrado ahora" en el hero; cuando está
  cerrado, aviso + grilla de horarios y se deshabilita agregar al carrito
  y el CTA de pago. `Checkout` también corta si está cerrado.

## Estado actual — Tercer tipo de promo: % + promo en la carta (2026-09-08)

Migración `20260908150000_promo_porcentaje.sql`:
- `promos.tipo` ahora acepta `'porcentaje'` + columna `descuento_pct`
  (1-100). Motivo: `precio_especial` fija un precio plano y solo sirve si
  todos los productos valen parecido (trago $8000→$7000 ok, pero papas
  $5000 quedarían más caras). El % se adapta a cada precio.
- `calcular_descuentos_promo()` reescrita con la rama `porcentaje`
  (`round(precio * pct/100, 2)`) en el score y en el descuento. `nxm` y
  `precio_especial` sin cambios.
- `promos_vigentes(local_id)` — RPC que devuelve las promos activas ahora
  (día + franja ya chequeados) con su `producto_id`. La usa la carta.
- `AdminPromos`: tercer botón "Descuento %" + input, validación y resumen.
- `Carta` + `ProductoCard`: badge de promo (`-20%`, `3x2`, o "Promo") y
  precio tachado → precio con promo cuando hay una vigente. Es solo
  visual; el precio real lo recalcula `crear_pedido`/`previsualizar_pedido`.

**PENDIENTE APLICAR** (3 migraciones sin pushear):
`20260908130000_previsualizar_pedido`, `20260908140000_horarios_local`,
`20260908150000_promo_porcentaje` → `npx supabase db push`. Hasta entonces
el checkout no muestra el descuento y la carta no muestra abierto/cerrado
ni promos (degrada sin romper).

## Patrón de UI recurrente

"**Filtrar + multiseleccionar + aplicar**" aparece en 3 lugares: editor de
precios en masa, gestor de disponibilidad (agotado / corte de tragos), y armado
de promos. Conviene un componente reutilizable.

## Stack

- Vue 3 (Composition API) + Vite + Tailwind v4 (`@tailwindcss/vite`) + Vue Router
- Supabase (free tier): Postgres + Auth + Realtime + Storage
- Webhook de Mercado Pago → Supabase Edge Function (Deno)
- Hosting: Hostinger, SPA estática, mismo pipeline manual que `asiste`
- Esquema versionado en `supabase/` (schema.sql + migrations/) como en `asiste`

### Por qué este stack (y no Nuxt)

Nuxt con `/server/api` necesita un Node corriendo; el hosting compartido de
Hostinger no lo tiene. La única razón para Nuxt eran los webhooks de pago, y esos
se resuelven igual con Supabase Edge Functions. Con Vue+Vite el deploy es el
mismo que ya usa el usuario para `asiste`. Migrar a otro Postgres más adelante es
un `pg_dump`; lo propietario (Auth, Storage, Functions) queda aislado en helpers.

## Roadmap

| Hito | Qué | Cómo se prueba |
|---|---|---|
| **1** | Scaffold: proyecto corriendo + conexión a Supabase | `npm run dev`, ver "Supabase: conectado ✅" — ✅ cerrado |
| **2a** | Esquema: negocios, locales, roles, menú (categorías/productos/opciones/combos/promos) + RLS | Cargar datos a mano en Supabase, leerlos desde la app — ✅ cerrado |
| **2b** | Esquema: pedidos, pedido_items, estados por estación, delivery | Insertar un pedido a mano, verlo reflejado — ✅ cerrado |
| **2c** | Esquema: suscripciones, pagos, cron de vencimientos | Marcar un pago a mano, ver cambiar el estado del local — ✅ cerrado |
| **3** | Carta + carrito (Pinia) | Agregar productos, ver el total — ✅ cerrado |
| **4** | Checkout: retiro/delivery + método de pago | Crear un pedido de prueba — ✅ cerrado |
| **5** | Pantalla del local (KDS) con Realtime + sonido | Pedido en un dispositivo → aparece en otro — ✅ cerrado |
| 6 | Mercado Pago: preferencia (Edge Function) + webhook | Pago de prueba con credenciales de test |
| **7** | Seguimiento del pedido para el cliente (`/pedido/:id`) | Cambiar estado en el local → se actualiza en el celu — ✅ cerrado |
| — | Motor de promos (3x2, happy hour) en el carrito | Aplicar una promo y ver el descuento |
| 8 | Onboarding autogestionable + panel admin (dashboard) | Un dueño de prueba se registra y carga su local |

Estados del pedido (borrador): `pendiente_pago` → `pago_confirmado` /
`a_pagar_en_caja` → `en_preparacion` → `listo` → `entregado` / `despachado`
(+ `cancelado`).

## Estado actual — Hito 1 CERRADO ✅ (2026-09-07)

Proyecto Supabase creado: organización **TizDigital** (Free), proyecto
**sinfila**, región `sa-east-1` (São Paulo). URL:
`https://ivukiuowaykgdyvdxicd.supabase.co`. `.env` completo, `npm run dev`
muestra "Supabase: conectado ✅".

Nota técnica: el chequeo de conexión NO se puede hacer pegándole a la raíz
`/rest/v1/` (ahora exige la secret key). Se corrigió `App.vue` para pegarle a
una tabla inexistente y validar por el código de error (`PGRST205` = la key
es válida, solo falta la tabla).

Las API keys de este proyecto son el formato nuevo de Supabase:
`sb_publishable_...` (equivalente a la `anon` key, va en el frontend) y
`sb_secret_...` (nunca en el frontend).

## Estado actual — Hito 2a en progreso (2026-09-07)

`supabase/schema.sql` escrito: negocios, locales (con la suscripción/estado
vive acá, no en negocios, porque el cobro es por local), zonas_delivery,
super_admins, usuario_local_roles, categorias, productos, grupos_opciones,
opciones, combos, combo_items, promos, promo_productos + funciones de acceso
+ RLS completa.

Decisiones de diseño tomadas al escribir el esquema:
- El alta de negocio/local por RLS queda reservada al super-admin por ahora
  (`insert` solo si `es_super_admin()`). El alta autogestionable por el dueño
  se resuelve con una función dedicada en el Hito de registro/onboarding.
- El dueño puede editar la config de su local (`UPDATE` en `locales`) pero NO
  las columnas de suscripción (`estado`, `trial_hasta`) — se usan GRANTs a
  nivel columna de Postgres para bloquear eso, no solo RLS de fila.
- `categoria_id` en `productos` es `on delete restrict` (no se borra una
  categoría con productos adentro). `producto_id` en `combo_items` y
  `promo_productos` también `restrict` (sacar el producto del combo/promo
  antes de borrarlo).

**Cambio de flujo de trabajo (2026-09-07): Claude corre las migraciones.**
Antes: pegar `schema.sql` a mano en el SQL Editor. Ahora: Supabase CLI
(`npx supabase`) conectada directo a la base vía **Session pooler**
(`aws-0-sa-east-1.pooler.supabase.com:5432`, no la conexión directa —
IPv6-only en free tier, no llega desde acá). Credenciales en
`.env.supabase-cli` (gitignorado, nunca se commitea). Estructura estándar:
`supabase/config.toml` + `supabase/migrations/*.sql`, aplicadas con
`supabase db push`. `supabase/schema.sql` se eliminó — las migraciones son
ahora la única fuente de verdad. `supabase db query` permite correr SQL
suelto (sirve para cargar datos de prueba sin pedirle al usuario que copie
nada).

✅ Migración `20260907120000_base_multi_local_menu.sql` aplicada. Verificado
por REST que las 13 tablas existen y RLS está activo (`negocios` devuelve
`[]` sin sesión, como corresponde).

✅ Usuario de prueba creado (`cae55d9b-1f28-4ed6-a104-7f5c5045804e`), cargado
como `super_admins` y como `dueño` del local de prueba. Datos de prueba en
`supabase/seed.sql` (negocio "Bar de Prueba", local slug `bar-de-prueba`,
categorías Tragos/Comida, productos Fernet con Coca y Papas Fritas con un
grupo de opciones). Verificado por REST que se lee público lo que debe
(locales/categorias/productos/opciones) y NO lo que no debe (`negocios`
vacío sin sesión).

**Routing definido** (antes `/` y `/local` eran fijos, ya no):
- `/` → `Home.vue`, placeholder (acá va la landing/signup, Hito 8).
- `/:slug` → `Carta.vue`, la carta pública de ese local (lee `locales` por
  slug + `categorias`/`productos` vía `src/lib/locales.js`).
- `/panel/:slug` → `Local.vue`, placeholder del panel interno (KDS, etc. —
  se define bien en el Hito de onboarding/admin).

## Estado actual — Hito 3 en progreso (2026-09-07)

Carrito con **Pinia** (`src/stores/cart.js`), persistido en `localStorage`,
atado al slug del local (si el cliente entra a la carta de otro local, el
carrito se vacía solo). Line-items se mergean por producto/combo + mismas
opciones elegidas (2 papas "con cheddar" quedan en una sola línea con
cantidad 2, no en dos líneas separadas).

Componentes nuevos:
- `ProductoCard.vue` — muestra el producto; si tiene grupos de opciones
  (armado), los renderiza como chips seleccionables (primera opción
  preseleccionada) antes del botón "Agregar".
- `ComboCard.vue` — igual pero sin opciones.
- `CarritoResumen.vue` — barra fija abajo con los ítems, +/-, sacar, y total.

`src/lib/locales.js` ahora trae `grupos_opciones`/`opciones` anidados por
producto y también `combos`, todo con un solo viaje a Supabase (embeds de
PostgREST). Se agregó un combo de prueba ("Combo Previa", $12.500) para
poder probar ese camino — documentado también en `supabase/seed.sql`.

✅ Probado por el usuario en el navegador: opciones, combos, cantidades,
sacar ítems y total funcionan como se esperaba.

## Estado actual — Hito 3 CERRADO ✅ (2026-09-07)

## Estado actual — Hito 4 en progreso (2026-09-07)

Función `crear_pedido(payload jsonb)` escrita y probada (2 migraciones: la
función + un fix a la validación de barrio de delivery). Expuesta a
`anon`+`authenticated` — cualquiera puede pedir, pero la función **recalcula
todo del lado del servidor** (precios de productos/combos/opciones, costo de
delivery contra `zonas_delivery`) y no confía en nada que mande el cliente.

Probado por API antes de tocar la UI:
- Pedido con 2 productos + 1 combo + opción con ajuste de precio → total
  calculado exactamente bien ($35.500).
- Rechaza carrito vacío y producto/combo inexistente con mensajes claros.
- Fix: el barrio de delivery ahora se valida siempre contra
  `zonas_delivery` (antes, con costo "fijo", se colaba cualquier texto).

Frontend nuevo:
- `src/lib/pedidos.js` — `crearPedido()` (llama al RPC) y `obtenerZonasDelivery()`.
- `src/views/Checkout.vue` — datos del cliente, retiro/delivery, zona +
  dirección, efectivo/transferencia (con alias + checkbox "ya transferí"),
  resumen, y confirmación con el número de pedido.
- Ruta `/:slug/checkout`. Botón "Ir al checkout" en `CarritoResumen.vue`.
- Si se entra a `/checkout` sin carrito (o con el carrito de otro local),
  redirige de vuelta a la carta.

Datos de prueba agregados a `bar-de-prueba`: alias de transferencia, costo
de delivery fijo ($900), mínimo de compra ($5000), y 2 zonas de delivery
(Centro $800, Norte $1200) — en `supabase/seed.sql`.

✅ Probado por el usuario: retiro + efectivo, delivery con/sin mínimo,
transferencia. Todo funcionando.

Ajustes hechos sobre la marcha:
- El botón "Confirmar pedido" **ya no se deshabilita** por validación —
  siempre es clickeable. Al apretarlo, si falta algo, hace scroll suave
  hasta esa sección y marca el/los campo(s) en rojo con "Campo obligatorio"
  (mejor UX que un botón gris sin explicación).
- **Bug de tipos corregido**: los `numeric` de Postgres llegan por PostgREST
  como *string* (`"6000.00"`), no como número JS. La mayoría de los cálculos
  no lo sufría porque una multiplicación de por medio los normalizaba sin
  querer, pero el costo de envío sumado directo podía pegotear el total
  (`"6000" + "900.00"` = concatenación, no suma). Se fuerza `Number(...)` en
  todos los puntos donde un precio/costo de la base entra a una cuenta:
  `ProductoCard.vue`, `ComboCard.vue`, `Checkout.vue`.

Ojo: las **promos no están aplicadas todavía** (motor de promos queda
pendiente, se suma en un hito aparte antes de dar por terminado el MVP).

## Estado actual — Hito 5 en progreso (2026-09-07)

**Sorpresa necesaria**: la pantalla del local necesitaba login (RLS solo deja
ver `pedidos` a dueño/staff/super-admin), así que se sumó de paso un login
mínimo — no estaba en el roadmap explícito pero era un prerrequisito real.

Nuevo:
- `src/lib/auth.js` (`iniciarSesion`, `cerrarSesion`, `obtenerSesion`) +
  `src/views/Login.vue`.
- Router: `/login`, y `/panel/:slug` ahora tiene `meta: { requiresAuth }` con
  un guard (`router.beforeEach`) que redirige a login si no hay sesión.
- Migración `20260907170000_realtime_pedidos.sql`: agrega `pedidos` a la
  publicación `supabase_realtime` (sin esto, Realtime no manda nada aunque
  el cliente se suscriba). La seguridad de "quién ve qué evento" la sigue
  resolviendo la misma RLS de siempre.
- `src/lib/pedidos.js`: `obtenerPedidosActivos`, `obtenerPedidoConItems`,
  `actualizarPedido`, `suscribirseAPedidos` (canal de Realtime sobre
  `postgres_changes` de `pedidos`, filtrado por `local_id`).
- `src/views/Local.vue` reescrita: pantalla del local real. Filtro
  Todos/Barra/Cocina, tarjetas por pedido con acciones según estado
  (Aceptar/Rechazar → Barra lista/Cocina lista → Entregar +
  "Avisar por WhatsApp" via `wa.me`), beep (Web Audio API, sin archivo de
  audio) al entrar un pedido nuevo.

El usuario de prueba (`cae55d9b-...`) ya es `dueño` de `bar-de-prueba` desde
el seed del Hito 2a, así que puede entrar directo con el email/password que
usó al crearlo en el dashboard.

✅ Probado por el usuario: Realtime funcionando (el pedido aparece solo, sin
recargar), ciclo completo Aceptar → Barra/Cocina lista → Entregar (pedidos
#5-8 llegaron a "entregado"). Dos ajustes pedidos y hechos:
- "Entregar" y "Avisar por WhatsApp" ahora aparecen **solo en el filtro
  Todos** (no en Barra/Cocina) — evita que se entregue algo a lo que le
  falta una estación. En los filtros de estación, un pedido "listo" muestra
  un aviso de que se entrega desde "Todos".
- Se borró a mano (vía `db query`, no hay botón de borrar en la UI a
  propósito — los pedidos no se eliminan por API, es auditoría) el pedido
  #3 de prueba que había quedado con 0 ítems de un test viejo por API.

## Ajuste posterior al Hito 5: estado "avisado" (2026-09-07)

Faltaba un paso entre "la cocina/barra terminó" y "el cliente ya se lo
llevó". Estados de pedido ahora: `pendiente → en_preparacion → listo →
avisado → entregado` (+ `cancelado`, `rechazado`).

- `listo`: uso interno, la preparación está lista.
- **"Listo para entregar"** (botón, solo en Todos): pasa a `avisado` — acá
  es donde en el Hito 7 se le va a avisar al cliente (push/página en vivo)
  que venga a buscarlo. El pedido **sigue en pantalla**.
- `avisado`: queda visible con **"Marcar entregado"** + **"Avisar por
  WhatsApp"** disponible todo el tiempo — por si el cliente tarda en
  aparecer, el staff puede reenviarle el aviso.
- `entregado`: recién ahí desaparece de la pantalla.

Migración: `20260907180000_estado_avisado.sql` (agrega `avisado` al check
constraint de `pedidos.estado`).

Botones también renombrados por pedido del usuario: "Aceptar" →
**"Iniciar preparación"**; en la vista Barra/Cocina, el botón por estación
es simplemente **"Pedido listo"** (al apretarlo, ese pedido desaparece de
esa vista puntual — solo sigue en "Todos" y en la estación que falte).

## Estado actual — Hito 5 CERRADO ✅ (2026-09-07)

## Estado actual — Hito 7 en progreso (2026-09-07)

Función `obtener_pedido_publico(p_id)` (security definer, misma lógica que
`crear_pedido`: no se expone la tabla, hace falta el UUID exacto — 122 bits,
no es adivinable). Devuelve solo lo necesario para la página del cliente:
número, estado, items, totales, nombre del local.

**Sin Realtime acá a propósito**: el cliente no tiene cuenta, no hay forma
de darle un permiso fino sin abrir una brecha (dejar que cualquiera lea
`pedidos` con el id igual permitiría listar si alguien más filtra distinto).
Se resolvió con **polling cada 5 segundos** mientras el pedido no llegó a un
estado final — para un solo local es carga insignificante, y evita toda esa
complicación de seguridad.

Nuevo:
- `src/views/SeguimientoPedido.vue`, ruta `/pedido/:id`. Mensaje según
  estado (distinto texto para retiro vs delivery en "avisado"/"entregado"),
  barra de progreso con los 5 pasos, resumen del pedido.
- El checkout ahora linkea a esta página ("Seguir mi pedido") al confirmar.

✅ Probado por el usuario: la página del cliente se actualiza sola con el
polling. Único ajuste pedido: la etiqueta "avisado" sonaba a jerga interna
— se tradujo a **"Listo para retirar"** / **"En camino"** (delivery) solo en
la UI (el valor en la base sigue siendo `avisado`, es un detalle de
sistema, no hacía falta tocar datos).

## Lección de tooling importante: `db query` NO sirve para probar RLS de tabla

El rol `postgres` con el que nos conectamos desde la CLI tiene
`rolbypassrls = true` (confirmado con `select rolbypassrls from pg_roles`).
Eso significa que **cualquier política RLS de una tabla se ignora** en ese
canal, sin importar qué `request.jwt.claims` se simule con `set_config`.

- Lo que SÍ sigue siendo válido probar así: los chequeos escritos a mano
  *dentro* de una función (`if not es_super_admin() then raise exception…`,
  como en `registrar_pago`) — no dependen de RLS, son lógica de la función,
  se ejecutan para cualquiera que la llame.
- Lo que NO se puede validar así: políticas RLS de tabla (`for all using
  (es_dueño_local(...))`, etc.) — hace falta pegarle a la API real
  (`curl` con la `anon key`, o un JWT real de un usuario autenticado).
- Ya validamos por la API real (curl + anon key) los casos de **lectura**
  en los Hitos 2a/2b (`negocios`/`pedidos` vacíos sin sesión). Para
  **escritura** (políticas del panel admin) todavía no hay una prueba end
  to end con un usuario autenticado real sin acceso — lo intenté con un
  usuario descartable por signup, pero Supabase exige confirmar el mail
  antes de poder loguearse, y no tengo la secret key para forzarlo a mano
  (a propósito, no la pedí). Confianza actual: las funciones que gatean la
  escritura (`es_dueño_local`) son las mismas que ya vimos funcionar de
  verdad en el KDS con el login real del usuario — misma lógica, mismo
  patrón, ya probado para lectura de `pedidos`.

## Estado actual — Hito 8a en progreso (2026-09-07): panel admin — menú

Arranca el Hito 8 (onboarding + panel admin), partido en pedazos como el 2.
Esta primera parte: estructura del panel + gestión de categorías/productos
— lo que más nos saca del hábito de cargar todo por SQL.

Nuevo:
- `src/lib/admin.js`: CRUD de categorías y productos (a diferencia de
  `lib/locales.js`, acá se ve todo — incluso lo no disponible).
- Rutas anidadas `/panel/:slug/admin` (Inicio) y `/panel/:slug/admin/menu`,
  con `AdminLayout.vue` (sidebar oscuro, distinto del look de la carta,
  como se había definido de entrada) pasando `local` a las vistas hijas
  vía `RouterView v-slot`.
- `AdminMenu.vue`: crear/renombrar/borrar categorías; crear/editar/borrar
  productos (nombre, descripción, precio, foto por URL, estación) +
  toggle de disponible. Los grupos de opciones se muestran de forma
  read-only por ahora (editarlos es un paso aparte).
- Errores de borrado por `on delete restrict` (categoría con productos,
  producto usado en un combo/promo) se traducen a un mensaje claro en vez
  de mostrar el error crudo de Postgres.
- Link cruzado KDS ↔ panel admin.

**Bug real encontrado y corregido**: el layout general (`App.vue`) envolvía
TODAS las rutas en una columna centrada de `max-w-3xl` — pensada para la
carta del cliente. El panel admin (que quiere ocupar toda la pantalla)
quedaba atrapado ahí adentro, angosto y corrido al medio. Fix: rutas
`meta: { bare: true }` (login, KDS, admin) se renderizan sin ese wrapper;
cada una trae su propio layout de punta a punta. De paso se sacó el
cartel "Supabase: conectado" de `App.vue` — ya cumplió su función en el
Hito 1, no tenía sentido mostrárselo a un cliente real para siempre.

**Primera pasada de diseño del admin** (a pedido del usuario, tomando ideas
de referencias sin copiarlas — se va a seguir sumando con el tiempo):
sidebar oscuro con acento índigo e íconos, topbar con el título de la
sección, cards `rounded-xl` con sombra suave, badges de color por estación
(barra morado / cocina naranja), switch visual en vez de checkbox para
"disponible".

**Gap encontrado por el usuario**: no había ninguna pantalla para combos —
ni se veían, ni había forma de sacar un producto de un combo para poder
borrarlo (el `on delete restrict` de `combo_items.producto_id` bloqueaba
todo sin dar salida). Se sumó una sección de **Combos** en `AdminMenu.vue`:
crear/editar/borrar combo, y agregar/quitar productos del combo — eso
libera al producto para poder borrarlo aparte.

**Segundo gap encontrado**: los combos nacían con `disponible = true` por
defecto — un combo recién creado, sin ningún producto cargado adentro,
aparecía vendible en la carta pública. Fix: `crearCombo` ahora los crea con
`disponible: false`, y se sumó el mismo switch visual que tienen los
productos para activarlo/desactivarlo a mano cuando esté listo. Se
encontró y ocultó un combo real que había quedado así ("Full papas
nashe", 0 ítems, estaba público) — no se borró, sigue ahí para
completarlo.

**Grupos de opciones (armado)**: sumada la gestión completa dentro del
form de edición de un producto — crear/editar/borrar grupos, crear/editar
(nombre y precio, autoguardado al salir del campo)/borrar opciones. El
resumen de la fila del producto ahora muestra el detalle completo
(nombre + precio de cada opción), no solo el nombre del grupo.

**Tercer bug encontrado (el del "no me deja borrar")**: al borrar un combo
que ya fue pedido alguna vez, Postgres pone en `NULL` el `combo_id` de esos
`pedido_items` viejos (a propósito, para no perder el historial). Pero el
check constraint de `pedido_items` exigía `combo_id` no nulo para todo ítem
tipo `combo` — chocaba directo contra ese `SET NULL` y bloqueaba el borrado
de cualquier combo ya vendido. Fix en
`20260908100000_fix_check_pedido_items_combo.sql`: ahora alcanza con que
un ítem `combo` no tenga `producto_id`; el `combo_id` puede quedar en null
después (significa "el combo se sacó del catálogo, pero el pedido
conserva su nombre/precio de la época").

**Mismo bug, del lado de `producto_id`**: al borrar un producto ya pedido
pasaba exactamente lo mismo (`pedido_items.producto_id` se pone en NULL,
chocaba con el constraint). El mensaje de error del admin además
**mentía** — decía "está en un combo o promo" para cualquier error que
tuviera la palabra "violates", así que mostraba esa causa aunque fuera
otra cosa. Fix en `20260908110000_fix_check_pedido_items_producto.sql`
(constraint ahora solo exige exclusión mutua, sin exigir no-nulo) +
`lib/admin.js` ahora conserva `error.code` y el admin solo muestra "está
en un combo" cuando el código es realmente `23503` (foreign key), no por
coincidencia de texto.

**Rediseño del alta de combos (a pedido del usuario)**: ya no se puede crear
un combo sin productos. El formulario de "Nuevo combo" ahora arma la lista
de productos (con cantidad) ANTES de crear nada, calcula un **precio
sugerido** (suma de esos productos) que se muestra tachado, y precarga el
campo de precio con ese valor — el usuario lo puede pisar con el precio
real del combo (ej. sugerido $15.000, precio real $12.000). Al guardar, se
crea el combo y todos sus ítems juntos, en un solo paso. También:
- El switch "Disponible" ahora **rechaza activarse** si el combo tiene 0
  productos (con un aviso).
- Si sacás el último producto de un combo publicado, se apaga solo.
- Se ocultó "Combo Bajon" (había quedado publicado con 0 productos, antes
  de este fix) — no se borró, se puede completar y reactivar.
- Se sumó un aviso "usar este precio" cuando el precio actual de un combo
  ya existente no coincide con la suma de sus productos (por si se le
  agregan/sacan ítems después de creado).

## Deploy — CERRADO ✅ (2026-09-08)

`git init` + repo en `github.com/aleortizzz/sinfila` (rama `main`).
Subdominio **`sinfila.tizdigital.com`** creado en Hostinger — DNS en
**Cloudflare** (no en los nameservers de Hostinger, igual que `asiste`):
registro `A`, host `sinfila`, IP `147.93.39.226`, modo **DNS only** (nube
gris, no proxied — para no interferir con la emisión del SSL de
Hostinger). SSL de Hostinger ya emitido automático (http → https 301,
https 200).

**Deploy automático con GitHub Actions** (`.github/workflows/deploy.yml`):
en cada push a `main`, corre `npm ci` + `npm run build` (con
`VITE_SUPABASE_URL`/`VITE_SUPABASE_ANON_KEY` como secrets, porque el build
los necesita horneados en el JS) y sube `dist/` por **FTPS** a Hostinger
con `SamKirkland/FTP-Deploy-Action`.

Cuenta FTP dedicada y acotada (no la general de la cuenta de hosting):
usuario `u452496377.sinfila`, directorio
`/home/u452496377/domains/tizdigital.com/public_html/sinfila` (la cuenta
queda "encerrada" ahí, por eso `server-dir: ./` en el workflow y no
`/public_html/sinfila/` de nuevo). Password guardado como secret de
GitHub (`HOSTINGER_FTP_PASSWORD`), nunca en el repo.

Probado end-to-end: push → Action corre → sube por FTPS → sitio online
con SSL → ruta profunda (`/bar-de-prueba`) sirve bien gracias al
`.htaccess` de fallback SPA que ya traíamos del Hito 1.

✅ Confirmado por el usuario: el segundo deploy (fix del `<title>`) se
reflejó bien. Pipeline de deploy 100% probado de punta a punta, dos veces.

## Estado actual — Hito 9a: motor de promos CERRADO ✅ (2026-09-08)

Migración `20260908120000_motor_promos.sql`: tipo `item_calculado`,
función `calcular_descuentos_promo()` (consulta SQL pura, no loop
imperativo) y `crear_pedido()` reescrita para resolver todos los ítems
primero, pedirles el descuento, y recién ahí insertar. Nunca se confía en
el cliente para el descuento — se recalcula todo server-side, igual que
precios y disponibilidad.

Reglas implementadas: sin apilar (una sola promo por producto, la de
mejor descuento para ESE producto puntual); un NxM agrupa TODAS las
líneas del pedido asignadas a esa promo **aunque sean productos
distintos** (ej. "3x2 en tragos de $8000" cuenta junto ISLA ROJA + KIWI
FHRESH); precio_especial es un descuento plano por unidad.

Bug de tooling encontrado y corregido en el camino: `unnest()` de un
array de tipo compuesto en Postgres **ya lo desarma en columnas por sí
solo** — tratar de capturarlo como una sola columna con alias
`t(fila_completa, ordinalidad)` desalinea todo (el primer campo real
termina pisando el nombre de la ordinalidad). Hay que aliasear los N
campos del tipo + 1 para la ordinalidad.

Probado con datos reales (no con Fernet/Papas — esos ya no existían, el
usuario los reemplazó por tragos reales probando el admin: ISLA ROJA,
KIWI FHRESH, POMELO HULK, PRIMAVERA DULCE, los 4 a $8000):
- 3x2 con 2× ISLA ROJA + 1× KIWI FHRESH (2 productos distintos, misma
  promo) → descuento agrupado correctamente ($8000 sobre $24000, con ~1
  centavo de diferencia por redondeo — aceptable).
- 2 unidades (no alcanza el mínimo de 3) → sin descuento, cobra completo.

Nota de precisión conocida: el reparto del descuento entre líneas puede
quedar hasta ~1 centavo desviado del valor exacto cuando la cantidad no
divide justo (redondeo por línea antes de sumar). No bloqueante para el
negocio real, documentado por si se quiere pulir después.

Endurecido de paso el check constraint de `promos` (2a): ahora exige
`n > 0`, `m >= 0` y `precio_especial > 0`.

## Estado actual — Hito 9b: admin de promos CERRADO ✅ (2026-09-08)

`AdminPromos.vue` (`/panel/:slug/admin/promos`, nuevo ítem en el sidebar):
crear promo (nombre, tipo NxM o precio especial, días, horario, y
productos incluidos — **obligatorio elegir al menos uno antes de crear**,
mismo aprendizaje que con los combos vacíos), activar/desactivar,
agregar/quitar productos de una promo existente, borrar. Para V1 no se
edita nombre/tipo/días/horario de una promo ya creada — si hay que
cambiarlos, se borra y se crea de nuevo (simplificación consciente).

También: `SeguimientoPedido.vue` ahora muestra la línea "Descuento
(promo)" cuando corresponde (el dato ya viajaba en `obtener_pedido_publico`
desde el Hito 7, solo faltaba mostrarlo).

Pendiente (anotado, no bloqueante): mostrar el descuento en el
**carrito antes de pagar** (hoy recién se ve en la confirmación/
seguimiento) — necesitaría repetir la lógica de promos en JS para el
preview, similar a como el precio de los combos se calcula en el cliente.

**Pendiente, más grande**: elegir una variante específica al armar un
combo (ej. "este combo lleva las papas con cheddar"). Hoy `combo_items`
no guarda qué opción va con cada producto, y ni siquiera `crear_pedido` ni
el KDS desarman un combo en sus partes — un pedido con combo hoy llega a
la pantalla del local como una sola línea sin detalle. Arreglarlo bien
implica: columna nueva en `combo_items`, cambios en `crear_pedido`, y
mostrar el detalle en el KDS. Queda para la próxima tanda.

Pendiente para cerrar el Hito 8a:
- [ ] Probar en el navegador logueado como dueño: crear categoría, crear
      producto, editarlo, tildar/destildar disponible, borrar, e intentar
      borrar una categoría con productos (debe avisar, no romper).
- [ ] Después de esto: config del local (horarios, branding, pago,
      delivery), edición de grupos de opciones/combos, y más adelante
      onboarding autogestionable + super-admin.

## Estado actual — Hito 7 CERRADO ✅ (2026-09-07)

## Estado actual — Hito 4 CERRADO ✅ (2026-09-07)

## Estado actual — Hito 2c CERRADO ✅ (2026-09-07)

Migración `20260907150000_suscripciones.sql` aplicada. Agrega a `locales`:
`precio_mensual`, `proximo_vencimiento`, `gracia_hasta`. Tabla nueva
`pagos_suscripcion` (historial). Funciones `activar_local()`,
`registrar_pago()` (ambas security definer, solo super-admin — chequeo
interno con `es_super_admin()`) y `actualizar_estados_vencidos()` (la corre
un **cron job de Postgres** todos los días a las 03:00 hora Argentina, vía
`pg_cron`). Ninguna de estas 3 funciones tiene UI todavía — eso es Hito 8.

Probado el ciclo completo con un local de prueba (`local-suscripcion-test`):
- `activar_local`: `pendiente_activacion` → `trial`, `trial_hasta` = hoy + 30. ✅
- **Seguridad**: un usuario cualquiera (no super-admin) NO puede llamar
  `registrar_pago` — se verificó que la llamada no dejó rastro. ✅
- `registrar_pago`: `trial` → `activo`, `proximo_vencimiento` = hoy + 1 mes,
  fila en `pagos_suscripcion` con el período cubierto. ✅
- Backdateando `proximo_vencimiento` al pasado y corriendo la función del
  cron a mano: `activo` → `gracia` (con `gracia_hasta` = vencimiento + 5). ✅
- Backdateando `gracia_hasta` y corriendo el cron de nuevo: `gracia` →
  `suspendido`. ✅
- Un local `suspendido` **desaparece de la carta pública** (confirmado por
  API, sin sesión) — un local `activo` se sigue viendo normal. ✅

Pendiente (a propósito, no bloquea nada): los avisos escalonados
("se da de baja en 3 días") son notificaciones (email/WhatsApp), no
esquema — se resuelven en el Hito 8 junto con el panel visual.

## Estado actual — Hito 2b CERRADO ✅ (2026-09-07)

Migraciones `20260907130000_pedidos.sql` (esquema) y
`20260907140000_fix_historial_estado_trigger.sql` (fix) aplicadas. Tablas:
`pedidos`, `pedido_items`, `pedido_estados` (auditoría), `pedidos_contador`
(interna, numeración diaria). Trigger `combos.estacion` agregado a 2a (para
el MVP un combo se prepara desde una sola estación).

Probado de punta a punta con pedidos de prueba reales:
- Numeración diaria por local (arranca en 1, atómica con `ON CONFLICT`).
- `requiere_barra`/`requiere_cocina` se completan solos según los ítems.
- `subtotal`/`descuento_promos`/`total` se recalculan siempre en el server
  a partir de `pedido_items` — nunca se confía en un total mandado por el
  cliente.
- KDS opción (b): con barra lista y cocina pendiente, el pedido queda en
  "en_preparación"; recién pasa a "listo" cuando terminan las dos.
- RLS: anónimo no puede LEER `pedidos` (privacidad de otros clientes), pero
  SÍ puede INSERTAR uno nuevo (checkout sin cuenta).

**Bug encontrado y corregido**: el trigger de auditoría escuchaba
`after update OF estado`, que en Postgres solo dispara si el UPDATE
menciona esa columna explícitamente — se perdía el "listo" cuando llegaba
como efecto lateral de marcar una estación. Fix: escuchar cualquier update
y dejar que la función filtre por "cambió de verdad".

**Hallazgo importante para el Hito 4 (checkout)**: un `INSERT` simple en
`pedidos` funciona perfecto para un cliente anónimo. Pero pedir que te
devuelva la fila (`Prefer: return=representation`, que es lo que hace
`.insert(...).select()` de `supabase-js` por default) **falla con RLS**,
porque el `RETURNING` interno de Postgres exige que la fila sea visible
también por la policy de `SELECT` — y esa policy es solo para staff/dueño
a propósito (para que un cliente no pueda listar pedidos ajenos). → El
checkout NO puede usar `supabase.from('pedidos').insert().select()`
directo. Necesita una **función RPC `crear_pedido(...)`** (security
definer) que cree el pedido + sus ítems de forma atómica y devuelva
explícitamente `id`/`numero` — ya estaba previsto para el seguimiento sin
login, esto confirma que también hace falta para la creación.

**Notas de tooling** (para no perder tiempo de nuevo):
- `supabase db query` con SQL inline como argumento es poco confiable en
  Windows (rompe comillas al pasar por `npx.cmd`) — usar siempre `-f archivo.sql`.
- `-f` ejecuta el archivo como una única sentencia preparada: no acepta
  varios comandos separados por `;`. Un `WITH ... AS (insert ...), ... AS
  (insert ...) SELECT ...` sí vale (es una sola sentencia); pero dos
  `UPDATE` separados por `;` no.
- Postgres no permite modificar la misma fila dos veces en una sola
  sentencia (ej. dos CTEs de `UPDATE` sobre el mismo `id`) — el resultado es
  impredecible (solo se aplica una). Pasos secuenciales sobre la misma fila
  van en llamadas separadas.
- El resultado de un `SELECT` final en un `WITH` que además hace inserts
  a veces no lo muestra la CLI (aunque el insert sí se aplicó) — para
  verificar, conviene una consulta de lectura aparte después.

## Estado actual — Hito 2a CERRADO ✅ (2026-09-07)

`Carta.vue` lee de punta a punta desde Supabase: entrando a `/bar-de-prueba`
se ve el local de prueba con sus categorías y productos. RLS confirmado
funcionando (público ve el menú, no ve `negocios`).

Pendiente en general (no bloquea el Hito 2a): `git init` + primer commit,
definir el hosting final del subdominio `sinfila.tizdigital.com`.

## Deploy (cuando toque) — recordatorios de `asiste`

- Zipear `dist/` **fuera** de la carpeta del proyecto (OneDrive + Vite = `EBUSY`).
- `Compress-Archive` de PowerShell mete `\` en las rutas internas y rompe la
  extracción en hPanel. Armar el zip con `/` a mano (ZipArchive iterando archivos).
- Subir a `public_html/<carpeta>`, extraer, y dejar el contenido en la raíz de esa
  carpeta.
