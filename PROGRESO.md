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

## La carta ya no desaparece cuando un local está suspendido (2026-09-18)

Reportado por el usuario probando con "Bebidas Ortiz" (real, quedó
`suspendido` de tanto probar la herramienta de fechas): esperaba ver la
carta caída, pero seguía viéndola — porque estaba logueado como
dueño/staff de ese local en ese navegador, y la policy de `locales` deja
ver tu propio local sin importar el estado (para poder entrar a la
pantalla de "pagá para reanudar" en el panel). Confirmado con un `curl`
anónimo de verdad (sin su sesión): antes de este cambio devolvía `[]`
—no encontramos este local—, igual que si el local nunca hubiera
existido.

Cambio de diseño pedido: que un local `suspendido` **no desaparezca**
de la carta pública — que se siga viendo, marcada como cerrada, para no
confundir a un cliente que tenía el link guardado (no es que el negocio
cerró para siempre, es un tema de facturación). Separado de esto, un
control nuevo y exclusivo del super-admin para bajar la carta del todo
cuando de verdad haga falta (pedido del dueño, disputa), independiente
del estado de la suscripción.

- Migración `20260918110000`: columna `carta_deshabilitada` en
  `locales` (default `false`). `local_visible_publicamente()` ahora
  también incluye `suspendido` (antes solo trial/activo/gracia), y
  además exige `not carta_deshabilitada`. **`crear_pedido()` no
  cambió su chequeo** (sigue rechazando cualquier estado que no sea
  trial/activo/gracia) — o sea que ahora se puede VER la carta de un
  local suspendido, pero seguir sin poder pedir, verificado con un
  intento de pedido real vía API: `"Local no disponible"`. Se sumó
  además el chequeo de `carta_deshabilitada` a `crear_pedido` por las
  dudas.
- **Bug real encontrado en el camino** (migración `20260918111500` +
  fix en `20260918112000`): la policy de `SELECT` de la propia tabla
  `locales` tenía su condición hardcodeada, sin pasar por
  `local_visible_publicamente()` — al unificarla para que si pase por
  ahí, la función (que no era `security definer`) volvía a evaluar la
  misma policy al consultarse a sí misma dentro de su propio `select`,
  entrando en loop infinito (`stack depth limit exceeded`). Fix: la
  función pasa a `security definer` — mismo patrón que ya usan
  `rol_en_local`/`es_super_admin` y por la misma razón (evitar que una
  función se pise con la RLS de la tabla que consulta).
- `Carta.vue`/`Checkout.vue`: cuando `estado === 'suspendido'`, se
  fuerza `abierto = false` (sin ni siquiera consultar el horario del
  día) y se muestra un mensaje específico ("Este local no está
  aceptando pedidos por el momento") en vez del genérico de "cerrado
  ahora, abre a tal hora" — reutiliza el mismo mecanismo de `:cerrado`
  que ya deshabilita "agregar al carrito" y el checkout.
- `SuperAdmin.vue`: botón "Deshabilitar carta" / "Habilitar carta" por
  local (RPC `alternar_carta_local`, guardado con `es_super_admin()`) +
  badge "Carta deshabilitada" cuando está activo.
- **Probado con curl anónimo real** (sin sesión) contra `bar-de-prueba`
  (suspendido de verdad en producción): local y categorías visibles
  ✅; intento de `crear_pedido` rechazado con "Local no disponible" ✅;
  con `carta_deshabilitada=true` vuelve a devolver `[]` (desaparece del
  todo) ✅. Visualmente con Playwright en un contexto sin cookies: se
  ve el menú completo con el banner de "no acepta pedidos". Se revirtió
  `carta_deshabilitada` a `false` al terminar (el `estado=suspendido`
  real del local se dejó tal cual estaba, es dato real de las pruebas
  del usuario).

## Bug real: había que entrar en incógnito para ver un deploy nuevo (2026-09-18)

Reportado por el usuario, con la preocupación correcta: "si esto escala
a un local con 10 empleados, no puedo estar diciéndole a cada uno que
recargue/borre caché". El sitio tiene un service worker (PWA, vía
`vite-plugin-pwa`) para poder "agregar a inicio" en tablets — pensado
para el día a día, no para que cada deploy sea una odisea.

**Causa**: el navegador solo revisa si hay una versión nueva del service
worker cuando hace una **navegación real** (cargar la URL de cero). Acá
el problema es justo que esto es una SPA: alguien deja el panel/KDS
abierto todo el día sin volver a navegar nunca de verdad (todo el
movimiento interno es ruteo de Vue Router, no navegación de browser), así
que ese chequeo nunca se dispara solo. `registerType: 'autoUpdate'`
(ya estaba configurado) sí aplica la actualización y recarga solo en
cuanto la encuentra — pero nunca la estaba buscando activamente.

**Fix** en `src/main.js`: una vez que el service worker está listo, se
fuerza `registration.update()` cada 15 minutos y además cada vez que la
pestaña vuelve a estar visible (`visibilitychange`) — cubre tanto "lo
dejaron abierto todo el turno" como "cambiaron de app y volvieron". No
hizo falta tocar `vite.config.js` ni el modo de registro — el mecanismo
de "encontrar y aplicar sola" ya estaba, solo faltaba el disparador.

Nada de esto corre en `npm run dev` (el service worker solo se genera en
build de producción) — se verificó con `npm run build` + `vite preview`:
el SW queda activo, `registration.update()` resuelve sin error y sin
nada en consola. No se pudo simular un ciclo completo de "deploy nuevo
mientras un tab viejo sigue abierto" en este entorno (haría falta un
segundo build servido en paralelo); si después del próximo deploy real
alguien sigue viendo algo viejo pasados ~15-20 minutos, avisar para
revisar más a fondo.

## Formulario JC Barandas: botones fijos + confirmar envío con faltantes (2026-09-18)

Dos ajustes de UX pedidos después de ver el formulario armado:

- **Botones fijos** ("Guardar progreso" / "Enviar respuestas"): pasaron
  de estar al final del formulario a una barra fija abajo de toda la
  pantalla, visible sin scrollear. El `<form>` ahora tiene `pb-24` para
  que la barra fija no tape la última pregunta de la última sección.
- **"Enviar respuestas" ya no bloquea el envío** si falta algo
  obligatorio — antes tiraba un toast de error y no dejaba avanzar. Ahora
  abre un modal ("Te faltan responder N preguntas") con dos opciones:
  "Seguir respondiendo" (cierra el modal y scrollea a la primera
  pregunta sin responder — es el botón destacado, para no incentivar
  saltearse preguntas) o "Enviar de todas formas" (manda igual, aunque
  falte todo). El cliente puede no tener a mano un dato puntual (ej. la
  cantidad de reseñas de Google) y no tiene sentido que eso le trabe
  todo el cuestionario.

Probado con Playwright en desktop y mobile: los botones quedan
visibles sin scrollear al cargar la página; enviar en blanco abre el
modal con el conteo correcto (con singular/plural); "Seguir
respondiendo" cierra el modal y scrollea a la pregunta faltante; "Enviar
de todas formas" inserta igual en la base incluso con respuestas vacías
(caso límite probado a propósito) — fila de prueba borrada después.

## Formulario JC Barandas: pregunta "envíos al interior" (2026-09-18)

Se sumó `envios_interior` a la sección de zona geográfica, justo después
de `disponibilidad_viajar` (misma sección, pregunta hermana): distingue
"viajar a instalar" de "enviar el producto para que lo instale alguien
de la zona" — son dos modelos de negocio distintos con búsquedas de
Google distintas. Solo tocó el dato estático
(`src/data/jcbarandasSeoForm.js`); la tabla guarda todo en un jsonb
freeform, así que una pregunta nueva no pisa ni rompe respuestas ya
guardadas (ni las que estén en curso en el localStorage de alguien).

## Formulario JC Barandas: "Guardar progreso" (2026-09-18)

Pedido inmediato después de armar el formulario: al ser ~35 preguntas
sin login de por medio, hace falta poder cortar a mitad de camino y
retomar después. Como es una sola persona respondiendo (no hace falta
sincronizar entre dispositivos), el progreso se guarda en
`localStorage` del navegador, no en la base — evita la complejidad de
manejar "borradores" en `jcbarandas_seo_respuestas` para un caso de uso
tan chico. Al entrar a la página se restaura solo si hay algo guardado
(con un aviso arriba de "Recuperamos tu progreso"), y se borra
automáticamente al enviar el formulario completo. Probado con
Playwright: guardar → recargar → los valores vuelven tal cual quedaron;
enviar → `localStorage` queda limpio.

## Formulario de SEO para JC Barandas — feature aislado, sin relación con SinFila (2026-09-18)

Pedido puntual: el usuario tiene un cliente externo (`jcbarandas.com.ar`,
sitio institucional estático, sin base propia) al que le quiere pasar un
link con un cuestionario de SEO para completar. En vez de armar
infraestructura nueva para algo de un solo uso, aprovecha la base de
Supabase que ya está andando acá — pero **totalmente aislado** del
producto:

- Migración `20260918100000_jcbarandas_seo_form.sql`: tabla
  `jcbarandas_seo_respuestas` (`id`, `respuestas jsonb`, `creado_en`) sin
  ninguna relación con `locales`/`negocios`/`usuario_local_roles`. RLS
  con **una sola policy: INSERT para `anon`/`authenticated` con
  `check (true)`** — sin policy de SELECT/UPDATE/DELETE a propósito, así
  nadie puede leer las respuestas de otros vía la API pública (se
  consultan directo desde el Table Editor de Supabase, con el rol
  `postgres` que no pasa por RLS). Verificado con un `curl` anónimo
  contra el REST endpoint: devuelve `[]`, no las filas reales.
- `src/data/jcbarandasSeoForm.js`: el cuestionario completo (11
  secciones, ~35 preguntas) como dato estático — nada de esto sale de
  ningún panel ni se edita desde la UI.
- `src/views/JCBarandasSeoForm.vue`: página standalone en
  `/formulario-seo-jcbarandas`, ruta `bare` (sin el layout ni el fondo
  del resto del sitio), sin auth, sin link a ningún lado — no aparece en
  ningún nav ni pantalla de admin, se llega solo por URL directa.
  Respuestas se guardan como un único objeto `{ pregunta_id: valor }` en
  la columna `respuestas` (jsonb) — no se normalizó en columnas porque
  es un formulario de un solo cliente, sin reutilización futura.
- Estilo con la identidad visual real del sitio del cliente (scrapeado
  jcbarandas.com.ar): fondo azul marino oscuro (`#020617`), acento azul
  `#2563eb`, tipografía Figtree — para que el link se sienta parte de su
  marca y no de SinFila.
- **Probado de punta a punta** con Playwright: envío en blanco marca las
  13 preguntas obligatorias sin dejar avanzar; completando los campos
  mínimos, el insert llega bien a la tabla (verificado via SQL directo,
  incluida la forma correcta del array de un `multi_select`); después de
  eso se borró la fila de prueba. Fix de un bug real encontrado en el
  camino: el botón "Enviar respuestas" tenía `position: sticky`, lo que
  hacía que tapara el texto de la última pregunta visible al scrollear
  — se sacó el sticky, queda como botón normal al final del formulario.

## Backup diario automático a `tizdigital-backups` (2026-09-18)

Pedido explícito del usuario, con un patrón ya probado en otro proyecto
suyo (calcado tal cual, no rediseñado): `.github/workflows/backup.yml`
corre todos los días a las 6:00 UTC (3 AM Argentina) + disparo manual
(`workflow_dispatch`).

- Instala `postgresql-client-17` desde el repo oficial de PGDG (el de
  Ubuntu por default queda atrasado respecto a la versión de Postgres
  que corre Supabase, y `pg_dump` rechaza dumpear un server más nuevo
  que el cliente).
- `pg_dump` usa variables sueltas (`PGHOST`/`PGPORT`/`PGDATABASE`/
  `PGUSER`/`PGPASSWORD`/`PGSSLMODE=require`), no un connection string
  único — si la contraseña tiene `$` u otro carácter especial, el
  parseo de un URI se rompe.
- `set -o pipefail` antes de `pg_dump | gzip` + un `ls -la` después como
  chequeo visible en el log: sin esto, un `pg_dump` que falla a mitad de
  camino puede quedar tapado por un `gzip` que "sale bien" con un
  archivo casi vacío.
- Dump acotado a `--schema=public --no-owner --no-privileges` — nada de
  lo interno de Supabase (`auth`/`storage`/etc.).
- El dump **nunca vive en este repo** (es público/con colaboradores) —
  se clona `tizdigital-backups` (repo privado, centraliza backups de
  varios proyectos del usuario) con un token, se guarda en
  `tizdigital-backups/sinfila/db/YYYY-MM-DD.sql.gz`, se rota quedándose
  solo con los últimos 7 días, y se commitea/pushea de vuelta.
- Asumido `aleortizzz/tizdigital-backups` como dueño/repo (mismo dueño
  que este repo) — si no es así, corregir `BACKUPS_REPO` en el workflow.

Secrets a cargar en Settings → Secrets and variables → Actions del repo
`sinfila` (ninguno se probó end-to-end por el asistente — requeriría
pegar la contraseña real de la base y un token de escritura sobre un
repo privado en el chat; se le dejó la decisión al usuario):
`SUPA_HOST`, `SUPA_PORT`, `SUPA_USER`, `SUPA_PASSWORD` (Project Settings
→ Database → Connection parameters de Supabase, NO el connection
string), `BACKUP_TOKEN` (PAT de GitHub con permiso de escritura sobre
`tizdigital-backups`).

## Bug real: `fecha()` de SuperAdmin mostraba un día antes (2026-09-16)

Detectado por el usuario probando la herramienta de arriba: guardó
`proximo_vencimiento = 15/09/2026`, pero el resumen de la tarjeta decía
"Vence 14/9/2026". Causa: `new Date("2026-09-15")` sin hora se parsea
como **UTC medianoche** — en un huso horario detrás de UTC (Argentina,
UTC-3) eso cae en el día anterior al formatear en hora local. Los
`<input type="date">` no tenían el bug (comparan el string tal cual, sin
pasar por `Date`), por eso la discrepancia solo se veía en el texto de
arriba, no en los inputs debajo. Fix: mismo patrón que ya usaban
`BannerGracia.vue` y `AdminReportes.vue` (forzar `T00:00:00` antes de
parsear, para que caiga en hora local en vez de UTC).

De paso, aclaración importante que el usuario preguntó en el camino:
**poner una fecha no cambia `estado` por sí solo** — hace falta apretar
"Forzar chequeo de vencimientos ahora" para que se aplique (mismo
comportamiento que el cron real, que solo mira fechas una vez por día).

## SuperAdmin: fechas de suscripción editables a mano, para poder probar (2026-09-15)

Surgió al probar el banner de gracia: no había forma de "adelantar" el
vencimiento de un local sin esperar un mes real, ni sin pedirme que
hackee la base por SQL cada vez. El usuario pidió directamente un
calendario en el panel para poder jugar con las fechas él mismo.

- Migración `20260915140000_super_admin_fechas_manuales.sql`:
  - `fijar_fechas_local(local_id, trial_hasta, proximo_vencimiento,
    gracia_hasta)` — pisa las 3 fechas de un local a mano. Guardada con
    el mismo chequeo `es_super_admin()` que `activar_local`/
    `registrar_pago`; el dueño del local sigue sin poder tocarlas (los
    `GRANT` por columna de la migración base no cambiaron).
  - `actualizar_estados_vencidos_ahora()` — wrapper de
    `actualizar_estados_vencidos()` (el cron diario) para poder correrlo
    al toque desde el botón, en vez de esperar a la madrugada. La función
    del cron en sí sigue sin ser invocable directo por nadie más.
  - **Importante**: esto solo mueve fechas — no toca `estado` a mano. Si
    ya está `suspendido`, poner una fecha futura no lo reactiva por sí
    solo (esa lógica de "volver a activo" vive en `registrar_pago`, no
    en el chequeo de vencidos, que solo empuja *hacia adelante*:
    trial→gracia→suspendido). Para reactivar hay que usar "Registrar
    pago" como siempre.
- `SuperAdmin.vue`: cada local tiene un botón "Editar fechas" que
  despliega 3 `<input type="date">` (Prueba hasta / Vence / Gracia
  hasta) + "Guardar fechas"; arriba de la lista hay un botón global
  "Forzar chequeo de vencimientos ahora" que corre el chequeo sobre
  todos los locales de una.
- **Verificado sin necesitar volverse super-admin de prueba**: se
  intentó dar de alta un super-admin de test por SQL directo para poder
  loguearse y probar en el navegador — el clasificador de auto mode lo
  bloqueó (correctamente: es una escalada de privilegio, no una
  operación de datos común). En cambio se verificó lo importante sin
  ese riesgo: (1) ambas funciones nuevas rechazan a un usuario común con
  "Solo el super-admin puede…" (probado con el JWT real de un staff
  contra la base), y (2) el archivo `SuperAdmin.vue` compila limpio a
  través del transform de Vite (sin errores de sintaxis en template/
  script). No se probó el click real del botón en el navegador — si al
  usarlo aparece algo raro, avisar.

## Banner de aviso en estado de gracia (2026-09-15)

Pendiente desde el Hito 5 (suscripciones): cuando un local entra en
"gracia" (venció el trial o la suscripción, pero todavía no se suspendió
— 5 días de margen, ver `actualizar_estados_vencidos()`), nadie se
enteraba hasta que un día la carta desaparecía de golpe.

- `BannerGracia.vue`: componente chico, solo se pinta si
  `local.estado === 'gracia'`. Muestra la fecha límite (`gracia_hasta`)
  y cuántos días quedan ("hoy" / "mañana" / "en N días"). A propósito
  **no es dismisseable** — es una alerta de "se te corta el servicio",
  no algo para ignorar una vez y olvidar.
- Montado en las dos pantallas donde entra dueño/staff logueado:
  `Local.vue` (KDS) y `AdminLayout.vue` (panel admin). NO en `Carta.vue`
  (la pública) — al cliente del local no le interesa ni debería
  preocuparle la suscripción del negocio.
- `AdminLayout.vue` pasó de `flex` a `flex flex-col` en el contenedor
  raíz para que el banner ocupe todo el ancho arriba, con el sidebar +
  contenido como una fila aparte debajo (el sidebar sigue `sticky`, sin
  cambios de comportamiento ahí).
- `obtenerLocalPorSlug()` ahora trae `gracia_hasta` (no traía ninguna
  columna de suscripción antes). No es un dato sensible — la misma
  policy de `SELECT` que ya deja ver `estado` públicamente durante
  trial/activo/gracia deja ver esta columna también.
- Probado con Playwright contra la cuenta de prueba
  `borrar-antes-de-produccion@sinfila.test` (dueño de `bar-de-prueba`):
  se puso el local en `gracia` con `gracia_hasta` a 3 días, se confirmó
  visualmente el banner en KDS y admin (desktop, mobile, y con el drawer
  del menú abierto en mobile — no se pisan), y se revirtió el local a
  `activo` al terminar.

Pendiente (a propósito, no es parte de este pedido): avisos escalonados
antes de llegar a gracia (ej. "tu trial vence en 3 días") — quedan para
el Hito 8 junto con notificaciones por mail/WhatsApp.

## Bug real: cambiarte tu propio nivel de acceso no se aplicaba hasta recargar (2026-09-15)

Reportado por el usuario probando con `aortiz@pelba.com.ar`: siendo
administrador no veía "Historial" ni "Equipo" en el nav; después se bajó
el nivel a "Staff" desde el desplegable de Equipo y **siguió viendo
todo** como si nada hubiera cambiado.

**Primero se descartó que fuera un agujero de seguridad real.** Se
simuló el JWT de `aortiz` directo contra la base (sin pasar por el
front) para las tres funciones que gatean todo (`es_dueño_local`,
`puede_ver_facturacion`, `puede_editar_menu`): como administrador dan
`true/true/true`, como staff dan `false/false/false` — en el momento,
siempre. Es decir, cualquier lectura/escritura real (RLS o las funciones
RPC de reportes/historial) se frena igual de bien pase lo que pase en el
navegador.

**La causa real es front-end**: tanto el cache de permisos del router
(`cachePermiso` en `router/index.js`, pensado para no repetir el
RPC en cada click) como el `ref` de permisos de `AdminLayout.vue` se
calculan **una sola vez por sesión** (al loguearte / al montar el
layout) y nunca se invalidan. Si cambiás tu propio rol sin recargar la
página, ese cache queda desactualizado — podés seguir viendo links a
pantallas que ya no deberías, aunque al entrar esas pantallas no
muestren datos reales (porque el server sigue chequeando fresco al
pedirlos).

Con administrador pasa lo mismo al revés: si te promovieron a
administrador *durante* la misma sesión (en vez de entrar de cero ya
siendo administrador), el nav sigue mostrando lo que tenías antes de la
promoción hasta que recargás — por eso "de recién sumado no veía nada".

**Fix**: en `AdminEquipo.vue`, `cambiarNivel()` y `quitar()` ahora
detectan si la fila que se está tocando es la propia cuenta logueada
(comparando `usuario_id` contra la sesión actual). Si es así:
- Cambiar de nivel: confirma el cambio (aviso de que la página se va a
  recargar) y hace `window.location.reload()` después de guardar — la
  recarga reinicia el cache del router y el `permisos` de `AdminLayout`,
  así el nav/las rutas quedan correctas al toque.
- Sacarte a vos mismo del equipo: cierra sesión y manda a `/login`, ya
  que no te queda ningún rol en ese local.

No se tocó el cache en sí (sigue sirviendo para el caso normal: navegar
sin que tu propio rol cambie) — el fix es puntual al único momento en
que puede quedar desactualizado por una acción tuya.

## Ajuste menor: "Repetila" → "Confirmar contraseña" (2026-09-15)

Texto más prolijo en el modal de primer login (`PrimerCambioPassword.vue`).

## Bug real: no se podía re-sumar a alguien que se había "Quitado" (2026-09-15)

Reportado por el usuario con un caso real: sacó a `aortiz@pelba.com.ar`
del equipo, después quiso volver a sumarla con el mismo mail, y
"Sumar a alguien" le devolvía "Ya existe una cuenta con ese email."

**Causa**: "Quitar" borra la fila de `usuario_local_roles` pero nunca la
cuenta de `auth.users` — a propósito, documentado desde que se construyó
(por si se la vuelve a sumar más adelante). El problema era que "Sumar a
alguien" solo sabía **crear una cuenta nueva** (`auth.signUp()`), y
Supabase rechaza un signup con un mail que ya está registrado. No había
ningún camino para volver a vincular una cuenta existente.

- Migración `20260915130000_resumar_cuenta_existente.sql`:
  `sumar_usuario_existente(local_id, email, rol, ve_facturacion,
  edita_menu, nombre, telefono)` — busca la cuenta de auth por mail y, si
  todavía no tiene rol en ESE local, se lo asigna directo (sin pasar por
  signup). Si el mail no existe en absoluto, o la persona ya es parte del
  equipo, tira un error claro en vez de fallar silenciosamente.
- `crearCuentaStaff()` ahora es el fallback automático: intenta
  `auth.signUp()` como siempre, y si Supabase avisa "ya existe" (mismo
  chequeo de `identities.length === 0` que ya usaba para detectarlo), en
  vez de tirar error llama a `sumar_usuario_existente()`. Devuelve
  `{ usuarioId, yaExistia }` en vez de solo el id — el caller necesita
  saber cuál pasó, porque en el camino de "ya existía" **no hay
  contraseña nueva que mostrar** (no se pasó por signup).
- `AdminEquipo.vue`: la tarjeta de "Cuenta creada" ahora tiene una
  variante para este caso ("Ya tenía cuenta — la re-sumamos al equipo"),
  sin mostrar una contraseña falsa; el mensaje de WhatsApp avisa "entrá
  con tu cuenta de siempre" en vez de pasar credenciales inventadas.
- **Probado con la cuenta real del reporte** (`aortiz@pelba.com.ar`,
  directo por API): confirmado que estaba en 0 roles tras el "Quitar"
  original; `sumar_usuario_existente` la re-sumó con éxito (nivel Menú,
  como tenía antes); un segundo intento sobre la misma persona rechaza
  correctamente con "Esa persona ya es parte de este equipo." La prueba
  de punta a punta en el navegador con una cuenta nueva chocó con un
  rate-limit de intentos de signup de Supabase (acumulado de tanto probar
  en esta sesión, no relacionado al bug) — no bloqueante, la lógica ya
  estaba probada a nivel API con el caso real.

## Ficha de empleado + reporte de productividad (2026-09-15)

Cierra los otros 2 pedidos de la misma tanda. Antes de tocar código se
acotó el alcance con el usuario (ambos eran los más grandes de los 4).

**Ficha de empleado**:
- Migración `20260915110000_ficha_empleado.sql`: 3 columnas nuevas en
  `usuario_local_roles` (`nombre`, `telefono`, `notas`). El teléfono ya se
  pedía al crear una cuenta (para el link de WhatsApp) pero se descartaba
  después de usarlo una vez — ahora se guarda. `listar_equipo_local`
  recreada para devolver las 3.
- `components/FichaEmpleado.vue`: modal con form completo (nombre,
  teléfono, notas) + datos de solo lectura (alta, último acceso, mail
  confirmado) + botón **"Guardar" explícito** — a diferencia de los
  toggles/selects de la pantalla (que guardan solos), acá es un form de
  varios campos con un textarea, mismo criterio que ya usan
  `AdminProductoForm`/`AdminConfig` para formularios largos.
- `AdminEquipo.vue`: botón "Ficha" por persona (incluida la fila del
  dueño — a propósito: `actualizarFichaEquipo` SÍ permite tocar la fila
  del dueño, a diferencia de `cambiarNivelEquipo`/`quitarDeEquipo`, porque
  nombre/teléfono/notas no son campos sensibles, solo `rol` lo es y ese
  sigue protegido por el trigger). La lista ahora muestra el nombre si
  existe (con el email como subtítulo), o el email solo si no hay nombre.

**Reporte de productividad**: nueva pestaña "Productividad" dentro de
Reportes (junto a "Ventas", comparten el mismo selector de período).
- Migración `20260915120000_reporte_productividad.sql`:
  `reporte_productividad(local_id, desde, hasta)` — usa
  `pedido_estados.changed_by`, que se graba desde el Hito 2b, sin
  necesidad de ningún tracking nuevo. Devuelve `general` (pedidos
  completados + tiempo promedio del local, creación→listo) y
  `por_persona` (pedidos manejados + tiempo promedio de preparación,
  en_preparación→listo, de cada uno). Guardada por `puede_ver_facturacion`
  — mismo permiso que el resto de Reportes.
  Nota técnica: la transición automática a "listo" (cuando termina la
  última estación pendiente, vía `promover_estado_si_listo()`) ya
  atribuye correctamente a quien la completó — no hizo falta lógica
  extra para eso.
- `AdminReportes.vue`: chips "Ventas"/"Productividad" (mismo patrón que
  `AdminMenu`/`AdminConfig`). El filtro de categoría y el checkbox de
  envío solo aplican a Ventas; el período es compartido entre las dos.
- Probado con los datos demo reales (338 pedidos): la consulta corrió
  bien y trajo números coherentes con la estructura esperada.

**Probado end-to-end en navegador**: crear/editar una ficha (incluida la
del dueño, sin error), la lista refleja el nombre nuevo, y la pestaña de
Productividad muestra los 2 números generales + la tabla por persona.
Datos de prueba (nombre/teléfono/notas puestos en las cuentas de test)
revertidos a null al terminar.

## Forzar cambio de contraseña en el primer login (2026-09-15)

Pedido del usuario: alguien que entra por primera vez con la contraseña
generada por Equipo debería tener que elegir la suya propia, para no
quedarse con algo tipo `hghergsidfnghskjdfhg` para siempre.

- Migración `20260915100000_forzar_cambio_password.sql`: columna
  `debe_cambiar_password` en `usuario_local_roles` (default `false`).
  `crearCuentaStaff` la setea en `true` al crear la cuenta.
  `marcar_password_cambiada()` — security definer acotada a `auth.uid()`
  (nadie puede tocar la fila de otro) — la vuelve a `false` una vez que la
  persona elige su propia contraseña.
- `lib/auth.js`: `debeCambiarPassword(localId)` (lectura simple, la RLS de
  `usuario_local_roles_select` ya deja a cualquiera ver su propia fila) y
  `cambiarMiPassword(nueva)` (llama `auth.updateUser` + la RPC de arriba).
- `components/PrimerCambioPassword.vue`: modal de pantalla completa, sin
  botón de cerrar (no se puede saltear) — montado en **los dos** puntos de
  entrada posibles (`Local.vue`/KDS y `AdminLayout.vue`), porque según el
  nivel de la cuenta el primer login puede caer en cualquiera de los dos.
- Mensaje de "Cuenta creada" en Equipo actualizado para avisar que va a
  pedir elegir contraseña propia la primera vez.
- **Probado de punta a punta**: cuenta nueva con `debe_cambiar_password`
  en true → aparece el modal al loguearse → lo completa → el modal
  desaparece → cierra sesión → probar la contraseña VIEJA falla (esperado)
  → la NUEVA entra directo, sin que el modal vuelva a aparecer. Cuentas de
  prueba borradas al terminar.

## Bug real: "/" no redirige a alguien ya logueado (2026-09-15)

El usuario reportó que "se desloguea todo el tiempo" — pero la sesión
nunca se perdía. Probado directo (cerrar el navegador del todo y
reabrirlo con el mismo perfil): la sesión sobrevive sin problema, Supabase
la persiste sola en `localStorage`. El problema real: **entra siempre por
la raíz del dominio** (`sinfila.tizdigital.com`), y esa ruta (`Home.vue`,
la landing de marketing) nunca chequeaba si ya había sesión activa — le
mostraba "Registrá tu local / Ya tengo cuenta" a cualquiera, esté logueado
o no. Lo interpretó como "me desconectó" cuando en realidad nunca hubo
sesión perdida, solo una landing que no sabía que ya estaba adentro.

- `Home.vue`: en `onMounted`, si hay sesión activa, redirige con la misma
  lógica que ya usa `Login.vue` tras loguearse (`soySuperAdmin()` →
  `/superadmin`; si no, `miLocal()` → `/panel/<slug>/admin`). Sin sesión,
  se ve la landing de siempre.
- Probado en navegador: sin sesión, `/` muestra la landing normal; con
  sesión activa, redirige solo a `/panel/bar-de-prueba/admin` sin que el
  usuario vea la landing ni tenga que loguearse de nuevo.

## Equipo: estado de la cuenta + restablecer contraseña (2026-09-14)

3 mejoras pedidas por el usuario tras cerrar el rediseño de niveles:

- **Badge "Mail sin confirmar"** (ámbar) cuando `email_confirmed_at` es
  null — evita el llamado confundido de "no puedo entrar" cuando en
  realidad falta clickear el link del mail.
- **"Última vez: dd/mm/aaaa, hh:mm"** por persona (o "Nunca entró") — útil
  sobre todo para el caso que motivó "Administrador": un dueño ausente
  que quiere ver de un vistazo quién usa la cuenta de verdad.
- **Botón "Restablecer contraseña"** por persona — dispara
  `pedirResetContrasena()` (la misma función que ya usa `/recuperar`,
  reusada tal cual). Resuelve el caso de alguien que perdió el mensaje de
  WhatsApp con la contraseña original: antes había que borrar y recrear
  la cuenta entera (perdiendo el nivel de acceso cargado), ahora no.

- Migración `20260914130000_equipo_estado_cuenta.sql`: `listar_equipo_local`
  recreada (drop+create, cambia el shape) sumando `email_confirmado`
  (`email_confirmed_at is not null`) y `ultimo_acceso`
  (`last_sign_in_at`) — sin RLS nueva, es el mismo guard `es_dueño_local`
  de siempre.
- **Hallazgo al probar**: la cuenta de prueba "staff plano" apareció con
  `ve_facturacion: true` (mostraba "Cajero" en vez de "Staff"). Confirmado
  que es **arrastre de datos de prueba** de tanto testear en la misma
  sesión larga (no encontré con certeza cuál de las tantas pruebas lo
  pisó) — no un bug de la lógica de permisos, que se verificó a fondo por
  API directa en rondas anteriores. Corregido a mano; sirve como
  recordatorio de que las cuentas de prueba persistentes pueden acumular
  estado espurio en sesiones de testing largas.
- Probado: el botón de restablecer efectivamente pega contra
  `auth.resetPasswordForEmail` (confirmado con un 429 real de "esperá X
  segundos" cuando se probó dos veces seguidas contra la misma cuenta —
  de paso, confirma que el toast rojo de error funciona con un caso real,
  no simulado).

## Equipo: pestañas Agregar / Ver equipo (2026-09-14)

Último ajuste de layout: la pantalla tenía el form de alta y la lista del
equipo apiladas una debajo de la otra. Pasó al mismo patrón de chips que
ya usan `AdminConfig.vue` y `AdminMenu.vue` (`SECCIONES` + `v-show`) — dos
pestañas, **"Agregar"** (default) con el form de alta + la tarjeta de
"Cuenta creada", y **"Ver equipo"** con la lista para editar nivel o
sacar gente. Probado en navegador: cambiar de pestaña oculta/muestra el
contenido correcto y volver a "Agregar" no pierde nada.

## Equipo: redacción final de las descripciones (2026-09-14)

El usuario propuso catalogar los niveles como "Nivel 1/2/3/4 + Administrador"
en vez de nombres. Se lo desaconsejé: la numeración secuencial implica una
escalera donde cada nivel contiene al anterior, pero el modelo real no es
lineal — Cajero (ve facturación) y Menú (edita productos/promos) son dos
permisos **paralelos**, no un nivel 2 y un nivel 3 uno arriba del otro.
Numerarlos así hubiera sugerido, por ejemplo, que "nivel 3" incluye "nivel
2", cuando en realidad son independientes — Encargado es la única
combinación que sí es una suma real de los otros dos.

Se mantuvo el esquema de nombres, pero se adoptó el estilo de descripción
que propuso el usuario (describir a la PERSONA/trabajo, no la
funcionalidad):

- Staff: "Para quienes solo preparan y entregan pedidos."
- Cajero: "Para quienes además cierran caja y necesitan ver la
  facturación del día."
- Menú: "Para quienes cargan productos, combos y promociones."
- Encargado: "Para quienes supervisan todas las tareas: cierran caja y
  manejan el menú."
- Administrador: "Para gestionar la configuración del local y los roles
  del equipo — incluye todos los permisos anteriores."

Nota sobre por qué "Pedidos (KDS)" no se repite en cada frase corta
(el usuario preguntó): es la base común a los 5 niveles, no algo que
distinga a uno del resto — por eso se menciona en Staff (ahí es el 100%
de su alcance) pero no en los demás, cuyo propósito es decir qué se
**suma** sobre esa base. El desglose exacto y completo (incluido el ✅ de
Pedidos en los 5) ya lo muestra el desplegable de cada nivel.

## Equipo: detalle desplegable por nivel (2026-09-14)

Último ajuste de UX sobre Equipo el mismo día: cada nivel en "Nivel de
acceso" ahora tiene una flechita a la derecha que despliega un checklist
✅/❌ de las 5 capacidades (Panel de pedidos, Facturación, Menú, Equipo,
Configuración), sin perder la descripción de una línea que ya estaba.

- `lib/admin.js`: cada entrada de `NIVELES_EQUIPO` suma un objeto
  `capacidades` (las 5 flags explícitas) + `CAPACIDADES` (un solo lugar
  con las 5 etiquetas, en el orden en que se muestran).
- `AdminEquipo.vue`: el botón de la flecha usa `@click.prevent` — hace
  falta porque está anidado dentro del `<label>` del radio, y sin
  `.prevent` el click se propaga y termina disparando también la
  selección del nivel (el comportamiento nativo de un `<label>` es
  reenviarle el click a su control asociado). Verificado en navegador:
  abrir el desplegable de "Cajero" o "Administrador" no cambia la
  selección actual.

## Rol "Administrador" + rediseño de Equipo + toasts (2026-09-14)

Tercera vuelta sobre permisos el mismo día. Pedido del usuario: alguien con
el mismo poder que el dueño (para dueños "ausentes" que no quieren
gestionar el equipo ellos mismos), pero **el dueño real sigue siendo uno
solo** — el creador original vía `registrar_negocio()`. Además: la UI de
presets+checkboxes de la vuelta anterior quedó confusa, y pidió feedback
visual real al guardar (toast, no un botón "Guardar" — eso rompería la
consistencia con el resto de la app, que ya guarda al toque en todos los
switches).

**Nombre**: descartamos "superadmin" para esto — ese nombre ya lo usa la
app para el dueño de la plataforma (TizDigital, `/superadmin`, todos los
locales). Usar el mismo nombre para "co-dueño de un solo local" iba a
confundir en dos meses. Quedó **"Administrador"**.

**Riesgo que el usuario no pidió pero se desprendía de su propia regla**:
si administrador y dueño hacen exactamente lo mismo, y administrador
incluye "gestionar equipo", un administrador podría en teoría sacar o
degradar al dueño real. Se cerró con un trigger en la base (no solo en el
front), verificado con un ataque real: un administrador pegándole directo
a la API REST para cambiarle el rol al dueño real rebota con
`"No se puede cambiar el rol del dueño del local."` — la protección vale
incluso salteando el frontend por completo.

- Migración `20260914120000_rol_administrador.sql`:
  - `usuario_local_roles.rol` ahora acepta `'administrador'` además de
    `'dueño'`/`'staff'`.
  - `es_dueño_local()` — la función de la que YA dependían todas las
    policies de menú/equipo/config/reportes — pasa a `rol in ('dueño',
    'administrador') or es_super_admin()`. Al ser el único punto de
    verdad, administrador queda con el mismo poder que dueño en TODOS
    lados de una sola vez, sin tocar ninguna policy/RPC de nuevo.
  - Trigger `usuario_local_roles_proteger_dueño`: bloquea `UPDATE` (cambiar
    el rol) o `DELETE` sobre cualquier fila con `rol = 'dueño'`. Corre para
    cualquier conexión, incluida la de `postgres` — si algún día hace
    falta tocar al dueño de verdad, hay que deshabilitar el trigger a mano
    (mismo criterio que se usó para cargar los pedidos de prueba).
- **Rediseño de `AdminEquipo.vue`**: se sacaron los presets + 2 checkboxes
  sueltos. Ahora es **un selector de "Nivel de acceso"** con 5 opciones
  (Staff/Cajero/Menú/Encargado/Administrador), cada una con una
  descripción de una línea de qué hace. Se usa igual al crear una cuenta
  (radios) y al editar una ya creada (un `<select>` por fila, con
  `nivelDeFila()` calculando cuál de los 5 corresponde a la combinación
  real de `rol`/`ve_facturacion`/`edita_menu` de esa persona). Promover a
  alguien a Administrador pide una confirmación explícita (`confirm()`) —
  a diferencia del resto, que guarda directo, porque es un cambio con
  mucho más peso.
  - `lib/admin.js`: `NIVELES_EQUIPO` (un solo lugar con los 5, label +
    descripción — la UI nunca hardcodea la lista), `nivelDeFila()`,
    `cambiarNivelEquipo()` (reemplaza a `actualizarPermisosEquipo`).
    `quitarDeEquipo` ahora excluye por `rol` distinto de `'dueño'` en vez
    de exigir `rol = 'staff'` — así también se puede sacar a un
    administrador (el trigger de la base protege al dueño real de todas
    formas).
- **Sistema de toasts genérico** (`lib/toast.js` + `components/ToastStack.vue`,
  montado una vez en `App.vue`): array reactivo simple, sin Pinia — mensaje
  verde/rojo/amarillo (éxito/error/advertencia) en la esquina inferior
  derecha, se autodescarta a los 3s. Pensado para reusarse en cualquier
  pantalla con guardado automático, no solo Equipo.
- Probado en navegador + directo por API: promover a administrador pide
  confirmación, aparece el toast verde, el nuevo administrador tiene
  acceso real (probado contra `listar_equipo_local`, dueño-only) y **no
  puede** tocar al dueño real ni saltándose el frontend. Cuenta de prueba
  revertida a Cajero al terminar.

## Bug de paso: el link "Panel admin" del KDS no seguía el permiso nuevo (2026-09-14)

El usuario le dio permiso de "Menú" a una cuenta real (`aortiz@pelba.com.ar`,
staff) desde Equipo, y esa cuenta seguía sin ver ninguna forma de llegar al
panel desde el header del KDS. Confirmado en la base que el permiso SÍ se
había guardado (el toggle guarda solo, no hace falta botón "Guardar") — el
bug estaba en `Local.vue`: el link "Panel admin" seguía condicionado a
`esDueño` nada más, de una pasada anterior a los permisos granulares.

- Fix: el link ahora se muestra si hay **cualquier** acceso a `/admin`
  (dueño, facturación o menú), no solo dueño.
- Segundo detalle en el mismo fix: el link apuntaba siempre a `/admin`
  (Inicio), que exige permiso de facturación — alguien con SOLO menú
  hubiera hecho click y rebotado de vuelta al toque. Ahora el destino se
  calcula: dueño/facturación → Inicio, solo-menú → directo a `/admin/menu`.
- Probado con los 4 perfiles de prueba: dueño y cajero van a Inicio, el de
  solo-menú va directo a `/admin/menu` y **no rebota**, staff plano no ve
  el link. Mismo patrón que el bug del cache de hace un rato — cambios de
  permisos nuevos hay que perseguirlos en todos los lugares que asumían el
  modelo viejo (dueño/staff binario), no solo en el router.

## Permisos granulares de staff (2026-09-14)

Pedido del usuario: separar más el equipo, no solo "dueño vs staff" — por
ejemplo, quien cierra caja necesita ver la facturación del día sin ser
dueño. Se evaluó un sistema abierto de checkboxes libres por persona y se
descartó a propósito: cada permiso suelto es un punto nuevo de seguridad
para diseñar y probar, y para un local de este tamaño no hace falta esa
flexibilidad. Se optó por **2 interruptores independientes** en vez de
rangos con nombre fijo — dan exactamente las 4 combinaciones reales de un
bar/kiosco, con una fracción del trabajo:

| | Ve facturación | Edita menú |
|---|---|---|
| Encargado | ✅ | ✅ |
| Cajero (cierra caja) | ✅ | ❌ |
| Solo menú | ❌ | ✅ |
| Staff (como antes) | ❌ | ❌ |

**Decisión de seguridad clave**: "gestionar equipo" y "configuración del
local" quedan **siempre dueño-only, sin excepción** — ni con estos 2
interruptores ni de ninguna otra forma. A propósito: si alguna vez esos
permisos fueran asignables, existiría el riesgo de que una cuenta de staff
comprometida se autoasigne más acceso desde la misma pantalla de Equipo.

- Migración `20260914110000_permisos_granulares.sql`: 2 columnas nuevas en
  `usuario_local_roles` (`ve_facturacion`, `edita_menu`), 2 funciones
  (`puede_ver_facturacion`, `puede_editar_menu` — cada una `es_dueño_local(...)
  OR el interruptor puntual`, así el dueño nunca necesita tener los
  interruptores en true a mano). Se recrearon con el nuevo guard:
  `estadisticas_local`, `reporte_local`, `historial_pedidos`,
  `top_productos_local` (facturación) y las policies de escritura de
  `categorias/productos/grupos_opciones/opciones/combos/combo_items/
  promos/promo_productos` (menú). `usuario_local_roles`/`locales` (equipo/
  config) no se tocaron — siguen 100% dueño-only.
- **Storage de imágenes (`imagenes escribe/actualiza/borra el dueno`)**:
  se hicieron folder-aware. El path es `<carpeta>/<local_id>/...` y antes
  solo miraba el `local_id` — si simplemente hubiera ampliado esas 3
  policies a `puede_editar_menu`, alguien con permiso de menú también
  habría podido pisar el logo/banner de Configuración (carpeta `locales/`,
  mismo bucket). Ahora solo las carpetas `productos`/`combos` usan
  `puede_editar_menu`; cualquier otra carpeta sigue exigiendo
  `es_dueño_local`.
- `AdminEquipo.vue`: 2 checkboxes al crear una cuenta + 4 botones de atajo
  (Encargado/Cajero/Solo menú/Staff que simplemente tildan las 2 casillas
  de una — no es un sistema aparte). La lista "Tu equipo" ahora deja
  editar esos 2 permisos por persona ya creada (`togglePermiso`, optimista
  con rollback si falla), sin tener que borrar y recrear la cuenta.
- Router: el `requiresDueño` único de todo `/admin` se partió en
  `meta.permiso` por ruta (`'dueño' | 'facturacion' | 'menu'`). El cache
  del guard pasó de `usuario:slug` a `usuario:slug:permiso` (mismo
  criterio que el fix de más abajo — nunca cachear sin el usuario en la
  clave). `AdminLayout.vue` ahora oculta del sidebar lo que cada quien no
  puede usar (antes solo bloqueaba, no ocultaba).
- **Probado en 3 capas, no solo la UI** (esto es acceso a plata, se probó
  a fondo): (1) matriz completa de rutas para dueño + 2 cuentas de prueba
  nuevas (cajero, solo-menú) + staff plano, todas dieron exactamente lo
  esperado; (2) confirmado que el bloqueo es real en RLS, no solo en el
  router — un cajero intentando `PATCH` un producto **directo por la API**
  (sin pasar por el front) no modifica nada, y el mismo `PATCH` con la
  cuenta "solo-menú" sí funciona; (3) UI de Equipo (presets, checkboxes,
  edición de una cuenta ya creada) probada de punta a punta. Sin errores
  de consola en ningún caso. Datos de prueba revertidos al terminar.
- **2 usuarios de prueba nuevos, mismo criterio de siempre (borrar antes
  de producción)**: `borrar-antes-de-produccion-cajero@sinfila.test`
  (ve_facturacion) y `borrar-antes-de-produccion-menu@sinfila.test`
  (edita_menu), mismo password que los anteriores.

## Bug real: el cache del guard `requiresDueño` bloqueaba al dueño real (2026-09-14)

El usuario reportó no poder entrar más a su propio panel con su cuenta real
(`aleortizjusto3@gmail.com`). Diagnóstico: la cuenta estaba perfecta (
confirmada, dueño de `bar-de-prueba`, `last_sign_in_at` reciente — el login
funcionaba) — el problema era el `cacheDueño` agregado en el bloque de
"Permisos staff vs dueño" de más abajo.

**La causa**: el cache estaba guardado solo por `slug`
(`cacheDueño.set(slug, esDueño)`). Si en la misma pestaña del navegador se
probaba primero con la cuenta de staff (quedaba cacheado `bar-de-prueba →
false`) y después se cerraba sesión y se entraba con la cuenta real
**sin recargar la página** (el logout de una SPA no recarga nada), el
guard seguía usando la respuesta vieja para ese slug — bloqueando al
dueño real aunque el backend le diera acceso sin problema.

**Fix**: la clave del cache pasa a ser `usuario_id:slug` en vez de solo
`slug`. Cambiar de cuenta ahora genera una clave nueva en vez de pisar/leer
la de otra persona.

- Reproducido y verificado en navegador headless: login staff → intenta
  `/admin/reportes` (bloqueado, cachea) → logout sin recargar → login con
  la cuenta dueño de prueba, misma pestaña → **antes del fix se hubiera
  quedado bloqueada; con el fix entra normal**.
- **Lección para la próxima vez que se cachee algo atado a permisos**:
  cualquier cache en memoria de una SPA tiene que incluir el usuario en la
  clave, no solo el recurso — el logout no resetea el estado de los
  módulos JS, solo la sesión de Supabase.
- Al usuario le quedó la pestaña vieja con el bug en memoria — alcanza con
  refrescar esa pestaña (F5) para que tome el fix, no hace falta nada más.

## "Equipo": botón directo de WhatsApp (2026-09-14)

Pedido del usuario después de probar "Equipo" en real: además de "Copiar
mensaje", un botón que abra WhatsApp con el mensaje ya cargado — mismo
patrón que ya usa el KDS (`linkWhatsapp` en `Local.vue`, `wa.me/<tel>?text=`).

- Campo **Teléfono (opcional)** en el form de alta. Si se carga, la
  tarjeta de "Cuenta creada" muestra **"Enviar por WhatsApp"** (abre
  `wa.me` en pestaña nueva) al lado de "Copiar mensaje" (que sigue estando
  siempre, con o sin teléfono).
  El mensaje se armó una sola vez en `mensajeInvitacion()` y lo comparten
  los dos botones — no hay dos copias del texto para mantener sincronizadas.
- Probado en navegador: el link generado normaliza bien el teléfono
  (`+54 9 11 1234 5678` → `5491112345678`) y el mensaje llega urlencodeado
  correcto. Cuenta de prueba borrada después.

## SMTP propio con Resend — CERRADO ✅ (2026-09-14)

Resuelve el pendiente de más abajo (rate limit de mail) el mismo día que
se encontró.

- Dominio nuevo verificado en Resend: **`sinfila.tizdigital.com`** (aparte
  de `asiste.tizdigital.com`, que ya usaba el otro proyecto del usuario en
  la misma cuenta de Resend — separados para no compartir reputación de
  envío).
- 5 registros DNS cargados en Cloudflare (zona `tizdigital.com`): DKIM
  (TXT), MX + TXT de SPF, CNAME, y un **DMARC** en modo `p=none` agregado
  a mano (Resend no lo pide para verificar, pero sin él Gmail/Outlook
  igual desconfían — probablemente lo que faltó en el otro proyecto,
  donde los mails caían en spam).
- Supabase → Authentication → Emails → SMTP Settings: `smtp.resend.com:587`,
  usuario `resend`, password = API key de Resend con scope `sending_access`
  acotada solo a este dominio (no a toda la cuenta).
- Cloudflare: token API creado acotado a **`tizdigital.com` - DNS:Edit**
  únicamente (no la API key global) — así el peor caso de una fuga es
  limitado a los DNS de ese dominio.
- **Verificado end-to-end**: dos altas seguidas por API salieron sin rate
  limit (antes tiraba "Demasiados intentos" a la segunda), y el log de
  Resend confirma `delivered` desde `"SinFila" <no-responder@sinfila.tizdigital.com>`.
  Cuentas de prueba borradas después.

## Pendiente encontrado al probar "Equipo": rate limit de mail (2026-09-14)

Probando "Equipo" a mano, dos altas seguidas dispararon "Demasiados
intentos, probá de nuevo en un rato" (`esp()` ya lo traduce). Causa: el
servicio de mail que trae Supabase por default (sin SMTP propio) tiene un
límite de pocos mails/hora **no configurable** — es solo para desarrollo,
no aguanta uso real. No es un bug de "Equipo": el mismo límite le pega a
`/registro` (alta de un local nuevo) y a recuperar contraseña.

**Plan**: migrar a SMTP propio con **Resend** (Authentication → Emails →
SMTP Settings en Supabase). El usuario ya usa Resend en otro proyecto —
ahí los mails caían en spam, probablemente por dominio sin verificar del
todo (falta común: SPF+DKIM sin DMARC). DNS de `tizdigital.com` está en
Cloudflare (mismo lugar que el registro A de `sinfila.tizdigital.com`).

**Pausado a pedido del usuario** (2026-09-14) — no bloquea el resto del
trabajo, sí bloquea probar más de 1-2 veces por hora cualquier flujo que
mande mail de confirmación.

## "Equipo": alta de cuentas de staff sin SQL (2026-09-14)

Cerraba el gap real que quedó anotado en el bloque anterior: no había
ninguna forma de crear una cuenta de staff sin que Claude lo hiciera a
mano por SQL. Pedido del usuario, con el nombre "Equipo" (evitando algo
tan literal como "Agregar empleados") y como ítem propio del sidebar
(dueño-only, ya cubierto por el guard `requiresDueño`).

**El problema técnico real**: esta app no tiene servidor propio (SPA +
Supabase, sin Edge Functions todavía), así que no hay forma de mandar una
invitación por mail de verdad sin agregar infraestructura nueva (una Edge
Function con la `service_role` key). La solución sin infra nueva: el dueño
carga el mail, el sistema genera una contraseña, se muestra una sola vez en
pantalla para pasarla por WhatsApp — mismo patrón manual que ya usa el KDS
para avisar "pedido listo". El empleado confirma su mail como cualquier
alta nueva (mismo flujo que `/registro`).

- Migración `20260914100000_equipo_local.sql`: `listar_equipo_local(local_id)`
  — security definer, guardada por `es_dueño_local`, hace el join con
  `auth.users` para traer el email (esa tabla no es accesible directo desde
  el cliente).
- `lib/supabase.js`: `crearClienteAislado()` — un segundo cliente de
  Supabase con `persistSession: false`. Necesario porque `auth.signUp()`
  en el cliente normal **pisa la sesión activa** con la del usuario recién
  creado — así el dueño no se desloguea al crear una cuenta ajena. Truco
  estándar de Supabase para este caso sin backend propio.
- `lib/auth.js`: `esp` (el traductor de errores de Supabase a español) pasó
  a exportarse — se reusa tal cual para los errores de `signUp` acá
  (mail inválido, ya registrado, contraseña débil, etc.), sin duplicar la
  lista de traducciones.
- `lib/admin.js`: `generarContraseña()` (10 caracteres, sin 0/O/1/l/I para
  que se lea bien por WhatsApp), `crearCuentaStaff()`, `quitarDeEquipo()`
  (esta última solo borra filas con `rol = 'staff'` — a propósito nunca
  toca la fila del dueño desde esta pantalla).
- `AdminEquipo.vue` (`/panel/:slug/admin/equipo`): form de alta + tarjeta
  de "pasale estos datos" con botón de copiar (mismo mensaje armado con
  mail/contraseña/link de login) + lista del equipo actual con badge
  Dueño/Staff y botón "Quitar" solo en las filas de staff.
- **Bug real encontrado en la primera prueba**: probé con un email
  `@sinfila.test` (el mismo dominio que ya usan los 2 usuarios de prueba
  creados antes por SQL directo) y Supabase lo rechazó ("Ese email no es
  válido") — a diferencia de esos 2, que se insertaron directo en
  `auth.users` sin pasar por la validación real de la API de Auth,
  `auth.signUp()` sí valida el dominio y rechaza TLDs no entregables como
  `.test`. No es un bug de la app; se resolvió probando con
  `mailinator.com` (dominio real usado justamente para este tipo de test).
- Probado en navegador headless de punta a punta: crear cuenta → aparece
  en la lista como Staff → **la sesión del dueño no se pisó** (confirmado
  que el sidebar seguía mostrando su propio local) → Quitar la saca de la
  lista sin tocar las otras filas. Cuenta de prueba borrada del todo
  después (`Quitar` únicamente saca el rol, no borra la cuenta de auth —
  a propósito, por si se la vuelve a sumar más adelante).

## Permisos staff vs dueño: guard de rutas en /admin (2026-09-14)

Auditoría antes de tocar nada: el **backend ya estaba bien separado**
(RLS/RPC de Reportes, Historial, Menú, Promos, Config y suscripción ya
exigían `es_dueño_local`; staff nunca pudo tocar plata ni catálogo). El
hueco real era de **frontend**: `AdminLayout.vue` mostraba el sidebar
completo a cualquiera con acceso al local, así que un staff que clickeaba
"Reportes" se encontraba con una pantalla vacía/rota en vez de no ver el
link. Se descartó explícitamente construir la gestión de staff
(invitar/agregar cuentas) — hoy no existe ninguna UI para eso, es una
feature aparte y mucho más grande; esto solo prolija lo que ya había.

- `lib/auth.js`: `soyDueñoDelLocal(localId)` — wrapper de la función SQL
  `es_dueño_local` (ya tenía grant a `authenticated`, sin migración nueva).
  Devuelve true para dueño **o** super-admin, igual que el resto del
  backend — no hay que duplicar esa lógica en el cliente.
- `router/index.js`: el nodo padre `/panel/:slug/admin` suma
  `meta: { requiresDueño: true }` (los hijos heredan el meta, cubre las 11
  rutas de una sola vez). En `beforeEach`, si no es dueño, redirige a
  `/panel/:slug` (el KDS — el verdadero lugar de trabajo del staff) en vez
  de dejarlo entrar a un panel que le va a fallar todo.
  **Cacheado por slug** (`Map` en memoria): sin esto, cada click del dueño
  dentro de su propio `/admin` — la navegación de todos los días —
  dispararía 2 round-trips extra antes de cada pantalla. Con caché, el
  costo extra se paga una sola vez por sesión.
- **Segundo usuario de prueba** creado para testear esto:
  `borrar-antes-de-produccion-staff@sinfila.test` / mismo password que el
  de dueño, rol `staff` en `bar-de-prueba`. Mismo criterio: borrar antes de
  producción (`delete from usuario_local_roles where usuario_id =
  '094066eb-f0d7-4cb6-b8a0-71a2a4dd5daf'` + `auth.identities`/`auth.users`
  con ese id).
- Probado en navegador headless con las dos cuentas a la vez: el dueño
  navega `/admin/reportes` y `/admin/menu` sin fricción ni redirects; el
  staff, al loguearse, cae directo en el KDS, y cualquier intento de
  entrar a `/admin`, `/admin/reportes` o `/admin/config` por URL directa
  rebota solo de vuelta al KDS. Sin errores de consola en ninguno de los
  dos casos.
- ~~Detalle menor sin resolver: el link "Panel admin" del KDS sigue
  visible para staff~~ — **resuelto** (2026-09-14, pedido del usuario):
  `Local.vue` ahora llama a `soyDueñoDelLocal()` al cargar (mismo helper
  que ya usa el router) y el link solo se renderiza si es dueño. Probado
  con las dos cuentas de prueba: staff ya no lo ve, dueño sí.

## Renombre: "Disponibilidad" → "Pausar productos" (2026-09-11)

El usuario notó que "Disponibilidad" se iba a prestar a confusión el día
que exista stock: la disponibilidad real de un producto en la carta va a
ser el combinado de dos señales (`disponible` manual **Y** `stock > 0`),
pero el switch individual de cada producto va a seguir llamándose
"Disponible" para siempre (no se toca, está probado en toda la app).

- Pestaña y herramienta renombradas a **"Pausar productos"** (antes
  "Disponibilidad en masa"). Estados en la lista: **Activo/Pausado** (antes
  "Disponible/Agotado" — "Agotado" ya va a significar "sin stock" cuando
  eso exista, no hay que pisarlo). Botones **Reactivar/Pausar** (antes
  Activar/Desactivar). Filtro de estado: Activos/Pausados.
- Variables y función internas renombradas para que el código diga lo
  mismo que la UI (`pausaCategoriaId`, `pausaFiltrados`,
  `aplicarPausaMasa`, etc. — antes `disp*`).
- Mismo campo de datos por debajo (`productos.disponible`), cero cambio de
  esquema — es un renombre de superficie, no de concepto.
- Plan para cuando exista stock (anotado, no implementado): NO tocar este
  switch ni su nombre. El indicador combinado que vea el cliente en la
  carta (ej. el badge "Agotado" que ya existe) es un concepto nuevo y
  aparte, calculado a partir de `disponible AND stock > 0` — nunca
  guardado como un solo valor.
- Probado en navegador headless tras el rename: primera corrida dio un
  falso negativo (la UI no reflejaba el cambio a tiempo, aunque el UPDATE
  sí había llegado a la base — confirmado con una consulta directa),
  probablemente el server todavía terminando de recompilar tras el
  refactor. Corrida limpia inmediatamente después: pausar, recargar la
  página (persiste), reactivar — los 3 pasos ok, sin errores de consola.

## Disponibilidad en masa (2026-09-11)

Segunda herramienta en masa. Se evaluó explícitamente construir la versión
grande de stock (cantidad real que descuenta, con insumos) en lugar de
esta, pero se descartó por ahora — el usuario la había marcado como "para
mucho más adelante" y no hay necesidad urgente; construirla no habría sido
"más escalable", solo más alcance sin pedido real detrás. Esta sí resuelve
un caso concreto ("cerró la barra, apagá todos los tragos") sin tocar el
esquema.

- Pestaña nueva **Disponibilidad** en `AdminMenu.vue` (entre "Precios en
  masa" y "Stock" — quedan como conceptos separados: esta es on/off manual,
  "Stock" sigue siendo el placeholder de cantidad real a futuro).
- Mismo patrón que precios: filtro por categoría + filtro por estado
  (Todos/Disponibles/Agotados), checklist con "Seleccionar todos", dos
  botones **Activar**/**Desactivar** que aplican `actualizarProducto(id,
  {disponible})` en loop. Sin migración — reutiliza la columna que ya
  existe.
- **Fix de paso**: el botón "Aplicar" de precios en masa usaba `btn-ghost`
  (blanco, borde gris clarito) parado sobre un fondo `bg-slate-50` — casi
  sin contraste, no se leía como botón (lo notó el usuario en una
  captura). Cambiado a `btn-brand` (sólido) en ambos paneles, ya que es la
  acción principal de la barra, no un toggle neutro como los de al lado.
- Probado en navegador headless con el mismo usuario de prueba: filtrar
  "Comida", seleccionar todos, Desactivar → los 2 productos pasan a
  "Agotado"; filtrar "Agotados", seleccionar todos, Activar → vuelven a
  "Disponible". Sin errores de consola. Datos de prueba quedaron en su
  estado original (Disponible) al terminar.

## Menú por pestañas: Productos / Precios en masa / Stock (2026-09-11)

Pedido del usuario: separar la parte "de a uno" (alta y edición de
productos/combos) de la parte masiva, para que `AdminMenu.vue` no sea todo
una sola pantalla larga — sobre todo pensando en que van a sumarse más
herramientas en masa (stock, disponibilidad).

- Chips arriba (mismo patrón que `AdminConfig.vue`): **Productos**
  (categorías + productos + combos, como estaba antes), **Precios en
  masa** (la tarjeta del bloque anterior, ahora en su propia pestaña) y
  **Stock** (placeholder "todavía no está construido").
- **Bug encontrado y corregido en el camino**: la pestaña "Productos"
  quedaba en blanco. Causa: usé `v-show` sobre un `<template>` para
  agrupar categorías+combos sin un wrapper extra — pero `v-show` necesita
  un elemento real del DOM para aplicarle `display:none`, y `<template>`
  no se renderiza como elemento (Vue lo descarta al montar). `v-if` sí es
  válido sobre `<template>` (es justamente el caso de uso para agrupar sin
  wrapper); cambiado a `v-if` y quedó bien. Las otras dos pestañas usan
  `v-show` sobre un `<div>` real, ahí sí corresponde.
- Verificado en navegador (headless, mismo usuario de prueba): las 3
  pestañas cambian de contenido correctamente y volver a "Productos"
  mantiene todo (categorías, productos, combos) sin perder datos.

## Precios en masa (2026-09-11)

Primer pedazo del "Patrón de UI recurrente" (filtrar + multiseleccionar +
aplicar) que quedaba anotado más abajo — resultó que de las tres cosas que
esa nota imaginaba, solo el picker de productos de una promo existía
(y sin filtro ni "seleccionar todos"); precios en masa y disponibilidad en
masa no estaban construidos. Se arrancó por precios (pedido explícito del
usuario: automatizar tareas tediosas para los dueños — subir precios por
categoría es algo que hacen seguido por inflación).

- **Sin migración** — reutiliza `actualizarProducto()` y la policy RLS de
  `productos` que ya existían (las mismas que usa el switch de disponible).
- `AdminMenu.vue`: tarjeta nueva "Precios en masa" arriba de las categorías.
  Filtro por categoría + por precio actual exacto (para el caso "todos los
  de $8000 a $9000" dentro de una categoría con precios mezclados),
  checklist con "Seleccionar todos", y modo **Fijar precio** o **Ajustar %**
  (mismo look que el ajuste en masa de zonas de delivery en `AdminConfig`).
  Aplica con un loop secuencial de `actualizarProducto` + `confirm()`.
- **Probado de punta a punta** (headless, con Playwright instalado
  temporalmente — `npm install --no-save`, desinstalado después): login,
  filtro por "Tragos", seleccionar todos, +10%, confirmar → los 4 productos
  pasaron de $8.000 a $8.800 en el panel y en la lista principal a la vez
  (misma referencia reactiva), sin errores de consola. Precios de prueba
  revertidos a $8.000 después de probar.
- **Usuario de prueba creado para poder testear sin pedir contraseña**:
  `borrar-antes-de-produccion@sinfila.test`, rol `dueño` de `bar-de-prueba`
  (creado por SQL directo con `pgcrypto`, mismo truco que ya usábamos para
  cargar datos sin pasar por la confirmación de mail). El email ya lo dice:
  **borrar esta cuenta antes de salir a producción** — `delete from
  usuario_local_roles where usuario_id = '7e868c6e-493a-4a5d-9542-50f8eabfb801'`
  y después `delete from auth.identities/auth.users` con ese mismo id (o
  buscarlo por email).

Pendiente (más chico, mismo bloque): disponibilidad en masa (activar/
desactivar varios productos de una, para el caso "cerró la barra, apagá
todos los tragos"). Cuando se construya, ahí sí conviene extraer un
componente compartido con este filtro — con dos casos reales recién tiene
sentido la abstracción.

## Rate-limit en `registrar_negocio`: intentado y revertido (2026-09-11)

Cerraba el pendiente anotado en "Endurecimiento de seguridad": `registrar_negocio`
ya bloqueaba que un mismo usuario creara más de un local, pero no había techo
para una ráfaga de altas hechas con cuentas de auth distintas (spam de
`locales` en `pendiente_activacion`).

- Migración `20260911100000_rate_limit_registro.sql`: primer intento —
  cortar si ya se crearon 10+ locales en la última hora, **global** (todos
  los usuarios juntos, no por origen).
- **Revertido en `20260911110000`**: contar el total de altas del sistema
  castiga el *volumen*, no el *abuso* — un pico real de ventas (varios
  dueños genuinos registrándose la misma hora, que es justo lo que se
  quiere lograr con el producto) se hubiera bloqueado igual que un bot.
  La señal correcta es "muchos intentos desde el MISMO origen" (IP), y eso
  no se puede ver de forma confiable dentro de una función de Postgres —
  ahí solo se ve al usuario ya autenticado, no la IP del caller.
- **Dónde queda la protección real**: Supabase Auth ya aplica su propio
  rate-limit de signup por IP, *antes* de que se pueda siquiera llamar a
  `registrar_negocio` (hace falta una cuenta confirmada por cada intento,
  por el guard "un usuario = un local"). Si algún día hace falta más,
  el fix correcto es un **captcha** (Turnstile/hCaptcha) en `/registro`
  (`captchaToken` en `auth.signUp`, soportado nativo) — discrimina bot vs.
  humano sin penalizar el volumen de altas reales. Queda anotado como
  mejora futura, no urgente.

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

## Estado actual — Color del local en la carta + patrón "página de edición" (2026-09-08)

**1. La carta respeta el color del local.** Antes solo `var(--brand)` seguía
`color_primario`; las utilidades `brand-*` eran el rojo fijo de SinFila.
Nuevas clases en `style.css` que tiñen con `--brand` vía `color-mix`:
`.bg-brand`, `.tile-brand`, `.tile-brand-strong`, `.icon-brand-ghost`.
Aplicadas en `ProductoCard` (badge PROMO, placeholder de foto, chips de
opción → `chip-active`) y `ComboCard` (placeholder). Lo semántico queda
como está (verde "abierto", ámbar "cerrado", slate "COMBO").

**2. Promos: página de edición dedicada.** Nuevo patrón para formularios
largos (a pedido del usuario): en vez de un form inline que estira la
lista, un botón lleva a una página con todo el detalle y un "Guardar" que
muestra estado y vuelve a la lista.
- Rutas: `promos/nueva` y `promos/:promoId/editar` →
  `AdminPromoForm.vue` (sirve para alta y edición). Ahora SÍ se puede
  editar una promo (antes había que borrarla y rehacerla).
- `AdminPromos.vue` quedó como lista limpia: nombre + resumen + switch
  activa + Editar + Eliminar. Sin form inline.
- `lib/admin.js`: `obtenerPromoAdmin(id)`. La edición reconcilia
  `promo_productos` (diff agregar/quitar).
- **A futuro**: migrar menú (productos/combos/opciones) a este mismo
  patrón de página de edición.

**3. Configuración del local por pestañas.** `AdminConfig.vue` dejó de ser
una landing larga: chips **General / Branding / Pagos / Envíos**, se
muestra una sección por vez (`v-show`, el form sigue montado así "Guardar
cambios" guarda todo).

`npm run build` OK. Migraciones del turno anterior YA APLICADAS (corrió
`supabase db push`): `previsualizar_pedido`, `horarios_local`,
`promo_porcentaje`. Verificado contra la base: `local_abierto`,
`promos_vigentes` y `previsualizar_pedido` devuelven bien.

## Estado actual — Onboarding autogestionable + panel super-admin (2026-09-08)

Hito 8: alta de locales sin tocar SQL. Migración
`20260908170000_onboarding.sql`.

- **`registrar_negocio(nombre_negocio, nombre_local, slug)`** — RPC security
  definer que usa `auth.uid()`. Crea negocio + local
  (`pendiente_activacion`) + rol `dueño` + 7 filas de `horarios_local`.
  Valida slug (formato + único) y que la cuenta no tenga ya un local.
- **`listar_locales_superadmin()`** — todos los locales + datos del negocio,
  guardada por `es_super_admin()`. `es_super_admin()` ahora tiene grant a
  `authenticated` para que el front pueda preguntarlo.
- **`/registro`** (`Registro.vue`): crea la cuenta (`auth.signUp`) + llama a
  `registrar_negocio`. Si el proyecto exige confirmar el mail, muestra el
  aviso y el alta se completa al volver logueado. Sugiere el slug desde el
  nombre del local.
- **`/superadmin`** (`SuperAdmin.vue`, guard `requiresSuper` en el router):
  lista de locales con estado/fechas. "Activar (30 días)" con precio
  mensual → `activar_local`. "Registrar pago" con monto → `registrar_pago`.
- **`AdminLayout`**: si el local está `pendiente_activacion` o `suspendido`,
  muestra una pantalla de bloqueo en vez del panel.
- **`Login`**: sin `redirect` explícito, manda a cada uno a lo suyo
  (super → `/superadmin`, dueño → su panel, sin local → `/registro`).
- **`Home`**: CTA "Registrá tu local".

Pendiente: banner de aviso en estado `gracia` (funciona normal pero
habría que avisar "se corta en X días"); notificaciones por mail de la
gracia; y que el super-admin pueda suspender/reactivar a mano.

## Hito C — variantes de producto dentro de un combo (2026-09-09)

Un combo **hereda** los grupos de opciones de los productos que lo
componen. El cliente elige la variante al agregar el combo (ej. "combo con
gaseosa" → elegís el sabor). **El precio del combo no cambia** con la
variante (oferta de precio cerrado). Se elige una vez por producto (si el
combo lleva "2 Speed", va un solo sabor para los dos). Sin config nueva en
el admin: el combo toma lo que ya tengan sus productos.

- Migración `20260910160000_variantes_en_combo.sql`:
  - `resolver_opciones_combo(p_combo_id, p_opcion_ids uuid[], p_estricto)` —
    recorre los grupos de cada producto del combo, matchea las opciones que
    mandó el cliente (validando `disponible` y pertenencia real), y devuelve
    el snapshot `[{producto, grupo, opcion, precio_ajuste: 0}]`. Con
    `p_estricto` exige los grupos obligatorios.
  - `crear_pedido`: el ítem `combo` ahora llama a `resolver_opciones_combo`
    y guarda el snapshot en `pedido_items.opciones_elegidas`. El precio
    sigue siendo `combos.precio`.
  - `previsualizar_pedido` no cambia (el precio del combo no depende de la
    variante).
- `lib/locales.js` `obtenerMenu`: la query de combos trae los
  `grupos_opciones`/`opciones` de cada producto. Helper `limpiarGrupos`
  compartido con productos (ordena, filtra opciones no disponibles, tira
  grupos vacíos).
- `ComboCard.vue`: si algún producto del combo tiene variantes, muestra un
  bloque por producto con chips de opción (igual que `ProductoCard`).
  Manda `opciones` a `cart.agregar` con `precioAjuste: 0`. Sin variantes →
  se agrega de una como antes. La clave de línea del carrito ya separa por
  `opcionId`, así "Combo + Coca" y "Combo + Sprite" son líneas distintas.
- KDS (`Local.vue`), `PedidoDetalleModal.vue`, resumen del `Checkout.vue`:
  cuando la opción tiene `producto` (viene de un combo), se muestra
  "Gaseosa: Coca" en vez de solo "Coca".
- `AdminComboForm.vue`: cada producto del combo con variantes muestra un
  tag "con variantes" + nota aclaratoria (no cambian el precio).
- **Fix**: el form del combo no tenía campo de foto (la tabla y `ComboCard`
  ya soportaban `foto_url`). Se agregó `<ImageUpload>` igual que en
  productos, subiendo a `combos/<local_id>/foto-<ts>` en el bucket
  `imagenes` (la policy de storage solo valida el 2º segmento = local_id,
  así que la carpeta `combos/` no necesitó cambios).

## Reportes: filtro por categoría (2026-09-09)

Pedido del usuario: ver por período cómo se movió una categoría (p. ej.
"los tragos").

- Migración `20260910120000_reporte_por_categoria.sql`: `reporte_local` y
  `top_productos_local` suman `p_categoria_id uuid default null`.
  - NULL → igual que antes (totales por pedido).
  - Con id → se mira ítem por ítem: `ventas` = monto neto de los ítems de
    esa categoría, `pedidos` = pedidos que tuvieron al menos un ítem de la
    categoría, `ticket` = ventas / esos pedidos. `top` queda acotado a la
    categoría. Los ítems de combo no tienen categoría, quedan fuera (ok).
- `lib/admin.js`: `obtenerReporte(localId, { ..., categoriaId })` y
  `obtenerTopProductos(localId, desde, hasta, categoriaId)`.
- `AdminReportes.vue`: los dos `<select>` (categoría + período) pasan a
  una fila propia y fija bajo el título (antes el `justify-between` los
  saltaba de renglón cuando el subtítulo crecía con "· solo X"). "Todas
  las categorías" = sin filtro. Subtítulo muestra "· solo Tragos"; el
  gráfico aclara "sin envío ni combos, ventas netas de promo". El drill-
  down por día también respeta la categoría.

**Cómo se miden combos y promos** (para tener claro):
- Un **combo** es UNA fila en `pedido_items` (`combo_id` seteado,
  `producto_id` NULL, `precio_unitario` = precio del combo). Los
  componentes (1 Skyy + 2 Speed) NO son líneas del pedido, solo viven en
  `combo_items`. → Con filtro por categoría los combos quedan fuera
  (no tienen categoría). En "Todas" aparecen como "Combo X".
- Un **3x2**: la fila guarda `cantidad = 3` (salieron 3 tragos) y el
  `descuento_aplicado` por unidad cubre la unidad gratis. → "Más
  vendidos" cuenta **3 unidades**; el **monto es neto** (pagó 2). Todos
  los reportes usan `(precio_unitario - descuento_aplicado) * cantidad`,
  así que siempre muestran la plata que entró, no la de lista.
- "Todas las categorías" → `Ventas` = `sum(pedidos.total)` (neto de promo
  **+ envío**). Con categoría → `sum(ítems netos)` (**sin envío**). Por
  eso no suman exacto entre sí.
- Checkbox **"Incluir envíos en la facturación"** (migración
  `20260910140000`, `reporte_local` suma `p_incluir_envio` default true).
  Destildado resta `costo_delivery` de la facturación / ticket / gráfico.
  Solo se muestra sin filtro de categoría (con categoría el envío ya
  queda afuera).

## Filtro de período por mes (2026-09-09)

Pedido del usuario: en vez de "7 días / 30 días / 90 días", filtrar **por
mes**, y que el cambio "impacte en todo, que funcione en todos lados por
igual".

- **`src/lib/periodos.js`** (NUEVO, un solo lugar): `opcionesPeriodo(creadoEn)`
  arma la lista del `<select>` — Hoy · Últimos 7 / 30 / 90 días · un ítem
  por mes **desde que abrió el local** (`created_at` recorta la lista, no
  se muestran meses previos) · Desde el inicio. `periodoPorDefecto()` = el
  mes en curso. `rangoPeriodo(id)` traduce a `{ desde, hasta, prevDesde,
  prevHasta }` en `YYYY-MM-DD` (o `null` = desde que abrió el local / sin
  comparación). `'Nd'` = últimos N días con período anterior de N días.
  Un mes en curso corta `hasta` en hoy.
- `obtenerLocalPorSlug` ahora trae `created_at` para poder recortar los meses.
- Migración `20260910100000_reportes_rango.sql`: `reporte_local` e
  `historial_pedidos` pasan de `p_dias int` a **rango de fechas explícito**
  (`p_desde` / `p_hasta`, null = desde `locales.created_at`). `reporte_local`
  recibe además `p_prev_desde` / `p_prev_hasta` para el delta vs período
  anterior. Se dropearon las firmas viejas.
- `lib/admin.js`: `obtenerReporte(localId, { desde, hasta, prevDesde,
  prevHasta })` y `obtenerHistorial(localId, { desde, hasta, estado,
  limit, offset })`.
- `AdminReportes.vue` y `AdminHistorial.vue`: chips de período →
  `<select>` con `opcionesPeriodo()`, arranca en el mes en curso, ambos
  usan `rangoPeriodo()`. Misma lógica, mismo helper.

## Reportes v3 + detalle de pedido + sidebar mobile (2026-09-09)

- **Datos demo**: 338 pedidos ficticios sobre 35 días en `bar-de-prueba`
  (marcados con `direccion_referencia = 'seed'`; borrar con
  `delete from pedidos where direccion_referencia = 'seed'`). Se hizo con
  un DO block deshabilitando el trigger `pedido_local_abierto` alrededor.
- Migración `20260909180000`: `reporte_local` ahora devuelve `resumen`
  (pedidos / ventas / ticket del período) y `previo` (el mismo período
  anterior) para comparar. Saca `recientes`.
- Migración `20260909190000`: `pedido_detalle(pedido_id)` (dueño o staff) —
  header + cliente + dirección + pago + items con opciones/promo + totales
  + timeline de estados.
- Migración `20260909200000`: `historial_pedidos` agrega el `id` por fila.
- `AdminReportes`: fila de tarjetas Resumen con **delta ▲/▼ % vs período
  anterior**. Título "Ventas/Pedidos por día" (antes "Por día · 21 pedidos"
  confundía). Botón "Ver todo el período" prominente (pill negra) + estado
  "· todo el período" cuando no hay día seleccionado.
- `components/PedidoDetalleModal.vue`: sheet con el detalle. Se abre
  tocando una fila del historial.
- `AdminLayout`: el sidebar pasa a **drawer en mobile** (botón hamburguesa
  en el header, backdrop, scroll bloqueado, se cierra al navegar);
  `md:sticky` en desktop. `min-w-0` en el contenido para matar el scroll
  horizontal.

## Reportes v2 + Historial (2026-09-09)

Migración `20260909170000_reportes_v2.sql`:
- `top_productos_local(local, desde, hasta)` — más vendidos de un rango
  arbitrario.
- `historial_pedidos(local, dias, estado, limit, offset)` — tabla de
  pedidos con filtro de período/estado, paginada; acá SÍ entran
  rechazados/cancelados.

- `AdminReportes`: más padding a la izquierda del gráfico (números de 7-8
  dígitos ya no se pisan). Las **barras son clickeables** → filtran "Más
  vendidos" a ese día (barra seleccionada en negro + "Ver todo el
  período"). Se sacó la tabla "Últimos pedidos".
- `AdminHistorial.vue` en `/panel/:slug/admin/historial` + ítem "Historial"
  en el sidebar. Chips de período + select de estado + "Cargar más"
  (offset). Tabla: #, fecha, cliente+tel, entrega+barrio, pago, ítems,
  total, estado.

## Reportes (2026-09-09)

Migraciones `20260909150000_reporte_local.sql` +
`20260909160000_reporte_periodo.sql`: `reporte_local(local_id, p_dias)`
(`p_dias` = 7 / 30 / 90, o <= 0 = desde que se creó el local — se clampa a
`locales.created_at`)
(security definer, guardada por `es_dueño_local`) devuelve, para los
últimos 30 días: `serie` (día por día {fecha, pedidos, ventas}, con
generate_series para no saltear días sin ventas), `top` (10 productos más
vendidos por unidades, con monto neto de descuento), `recientes` (últimos
20 pedidos con # / fecha / cliente / items / pago / total / estado).

- `AdminReportes.vue` en `/panel/:slug/admin/reportes` + ítem "Reportes" en
  el sidebar. Gráfico de barras por día (toggle Ventas/Pedidos, hecho con
  divs, sin librería), tabla de más vendidos, tabla de últimos pedidos.
- `AdminHome`: las tarjetas de stats ahora son links — las de hoy/período
  van al reporte, "Productos activos" al menú.

## Estadísticas reales en el Inicio del panel (2026-09-09)

Hito 8 / "estadísticas". Migración `20260909140000_estadisticas_local.sql`:
`estadisticas_local(local_id)` (security definer, guardada por
`es_dueño_local` — el staff no ve facturación) devuelve un jsonb con
`pedidos_hoy`, `ventas_hoy`, `pedidos_7d`, `ventas_7d`, `ventas_mes`,
`productos_activos`. Todo en hora de Argentina, excluye
rechazados/cancelados.

`AdminHome.vue`: fila "Hoy" (pedidos, ventas, ticket promedio calculado en
el cliente, productos activos) + fila de contexto (7 días / mes). Los
placeholders "Pronto" quedaron.

## PWA instalable (2026-09-09)

`vite-plugin-pwa` (Workbox). Genera `sw.js` (precache de assets + CacheFirst
para las fuentes de Google), inyecta `manifest.webmanifest` y el
`registerSW`. `registerType: autoUpdate` (se actualiza solo en cada deploy).

- Manifest: name/short_name "SinFila", `display: standalone`, portrait,
  `theme_color #f5401f`, `background_color #faf7f2`. Iconos 192 y 512 +
  maskable 512 (cuadrado rojo con la "S", rasterizados de un SVG con Edge
  headless, en `public/`).
- `index.html`: `theme-color`, `apple-touch-icon`, metas
  `apple-mobile-web-app-*`, `viewport-fit=cover`.
- `public/.htaccess`: `AddType application/manifest+json .webmanifest`.
- `components/InstalarApp.vue`: barra "Instalar" en la carta cuando el
  navegador dispara `beforeinstallprompt` (Android/Chrome/Edge). El "ahora
  no" se recuerda en localStorage. iOS: Compartir → Agregar a inicio (el
  manifest le da nombre/icono/standalone).
- Requiere HTTPS → funciona en `sinfila.tizdigital.com`, no en `localhost`
  salvo `127.0.0.1`.

## Subir imágenes a Storage (2026-09-09)

Migración `20260909130000`: bucket público `imagenes` (5 MB, mime image/*).
Path `<carpeta>/<local_id>/<archivo>`; el 2º segmento es el local_id y las
policies de `storage.objects` habilitan insert/update/delete solo si
`es_dueño_local(<ese id>)`. Lectura pública (bucket public).

- `lib/storage.js` → `subirImagen(carpeta, localId, archivo, prefijo)`
  devuelve la URL pública.
- `components/ImageUpload.vue` → preview + subir/cambiar/quitar.
- `AdminConfig` (branding): logo y banner pasan de input-URL a upload.
- `AdminProductoForm`: la foto pasa a upload (funciona en alta y edición,
  el path usa el local_id, no el producto_id).
- La imagen se sube al toque; la URL se persiste con "Guardar cambios"
  (si no guardan, queda un objeto huérfano en el bucket — costo mínimo,
  se puede limpiar a futuro).

## Endurecimiento de seguridad (2026-09-09)

Auditoría del modelo de permisos. Lo que YA estaba sólido: `super_admins`
sin policy de escritura (nadie se hace super-admin por API); las funciones
de super-admin revalidan `es_super_admin()` server-side; los GRANT de
columna en `locales` impiden que un dueño toque su suscripción
(`estado`/`trial_hasta`/`precio_mensual`/…); `crear_pedido` recalcula todos
los precios server-side. El guard del router es solo UX.

Huecos tapados:
- Migración `20260909100000`: se quitaron las policies de INSERT de
  `pedidos` y `pedido_items` (y el UPDATE de `pedido_items`). Antes,
  cualquiera con el anon key podía insertar `pedido_items` con
  `precio_unitario` arbitrario y el trigger de totales lo sumaba. Ahora los
  pedidos SOLO se crean por `crear_pedido()` (security definer / bypassrls).
  Verificado: INSERT directo → HTTP 401; `crear_pedido` sigue OK.
- Migración `20260909110000`: `revoke update on pedidos` + grant solo de
  `(estado, barra_lista, cocina_lista)` a `authenticated`. Un dueño/staff
  ya no puede editar totales ni datos del cliente por API. El KDS solo toca
  esas 3 columnas.

Pendientes (no críticos, no tocan plata): separar permisos staff vs dueño
más fino a futuro. (El rate-limit de `registrar_negocio` se cerró después,
ver más abajo.)

## Recupero de contraseña (2026-09-09)

`/recuperar` (pide el mail → `resetPasswordForEmail` con
`redirectTo=<origin>/nueva-contrasena`) y `/nueva-contrasena` (usa la
sesión temporal de recuperación → `updateUser({ password })` → logout →
login). Link "¿Olvidaste tu contraseña?" en el login.
**Config Supabase**: hay que agregar en Auth → URL Configuration →
Redirect URLs: `http://localhost:5173/**` y
`https://sinfila.tizdigital.com/**` (o las rutas exactas de
`/nueva-contrasena`), si no el enlace del mail no vuelve a la app.

## Ajustes de onboarding (2026-09-08)

- **Registro**: un solo campo "Nombre del local" (negocio y local se
  llaman igual en el MVP). La URL se arma sola con el nombre; hay un
  "cambiar" para editarla. Ya no se pide "crear la URL" como paso aparte.
- **Aviso de verificación**: pantalla con "Confirmá tu correo" + botón
  "Ir a iniciar sesión" (antes decía "volvé a /registro").
- **Login**: link "Registrá tu local"; el error de Supabase "Email not
  confirmed" se traduce a un aviso ámbar con botón "Reenviar el correo"
  (`auth.resend`); "Invalid login credentials" → "Email o contraseña
  incorrectos".
- **Super-admin**: botón **Suspender** manual (migración
  `20260908180000_suspender_local.sql`, `suspender_local()` guardada por
  `es_super_admin()`). En un local suspendido, "Registrar pago" dice
  "Registrar pago y reactivar".

## Estado actual — "Obligatorio" real + disponibilidad por opción (2026-09-08)

- **`grupos_opciones.obligatorio`** ahora hace algo: obligatorio → primera
  opción marcada, el cliente elige sí o sí. No obligatorio → aparece un
  chip "Ninguna" y puede no elegir nada (`ProductoCard`).
- **`opciones.disponible`** (migración `20260908160000_opciones_disponible`):
  toggle por opción en `AdminProductoForm`. La carta no muestra las que
  están en false (y descarta el grupo si se quedó sin ninguna, en
  `lib/locales.obtenerMenu`). `crear_pedido` recreada con un guard que
  rechaza el pedido si el cliente mandó una opción no disponible (página
  vieja). El preview no se tocó (es solo display).

## Estado actual — Menú con páginas de edición (2026-09-08)

Se aplicó el patrón "lista → página de edición" (el de promos) al menú.
`AdminMenu.vue` bajó de ~770 a ~240 líneas.

- `AdminMenu.vue`: lista. Categorías se editan inline (son un nombre).
  Productos y combos: "Editar" / "+ Agregar" llevan a su página.
- `AdminProductoForm.vue` — `menu/productos/nuevo` y `.../:productoId/editar`.
  Datos del producto + el **armado** (grupos de opciones / opciones), que
  aparece recién en modo edición (necesita el id). Al crear, hace
  `router.replace` a la ruta de edición del nuevo para poder cargar el
  armado sin volver.
- `AdminComboForm.vue` — `menu/combos/nuevo` y `.../:comboId/editar`.
  Productos del combo con cantidad, precio sugerido (suma) tachado vs
  precio real, "usar suma". Se crea oculto; se activa desde la edición.
- `lib/admin.js`: `obtenerProductoAdmin(id)`, `obtenerComboAdmin(id)`.

Pendiente de este bloque: migrar también a este patrón cualquier form
inline que quede (por ahora no queda ninguno grande).

## Estado actual — KDS con vista Caja / Barra / Cocina (2026-09-08)

Rediseño de `Local.vue` (sin migración). Antes: pestañas Todos/Barra/Cocina
y un pedido `pendiente` ya se veía en Barra/Cocina.

- **Caja** (mostrador, ex "Todos"): ve todo el ciclo con todos los datos
  (cliente, tel, retiro/delivery + dirección, método de pago, si avisó la
  transferencia). El pedido entra `pendiente` y **solo se ve en Caja**.
  Botón contextual: "Confirmar pago e iniciar" (transferencia) /
  "Aceptar e iniciar" (efectivo) → pasa a `en_preparacion` y recién ahí se
  dispara a Barra/Cocina. También hace "Listo para entregar" → `avisado` →
  "Marcar entregado", y el link de WhatsApp.
- **Barra / Cocina**: solo pedidos `en_preparacion` que les tocan y que no
  marcaron listos. Tarjeta mínima: **#número, nombre del cliente, ítems de
  esa estación**. Sin pago, sin tipo de entrega, sin total. Un botón
  "Pedido listo".
- El gate de confirmación de pago = la transición `pendiente →
  en_preparacion`, que ahora solo se dispara desde Caja (no hizo falta
  columna nueva). Si entra MP en el futuro, el webhook puede hacer esa
  transición solo.

## Patrón de UI recurrente

"**Filtrar + multiseleccionar + aplicar**" — la idea original (2026-09-07)
era que esto iba a aparecer en 3 lugares: editor de precios en masa, gestor
de disponibilidad (agotado / corte de tragos), y armado de promos. En la
práctica solo se construyeron precios en masa (ver 2026-09-11) y un picker
simple de promos sin filtro — la nota de "componente reutilizable" queda en
pausa hasta que exista un segundo caso real (disponibilidad en masa).

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

~~Pendiente (anotado, no bloqueante): mostrar el descuento en el
carrito antes de pagar~~ — **resuelto** (ver "Preview de promo en el
checkout", 2026-09-08): `Carta.vue` llama a `previsualizar_pedido` con
debounce y le pasa el resultado a `CarritoResumen`, que ya muestra
subtotal tachado + "Descuento (promo)" + total real antes de llegar al
checkout. Verificado en el código el 2026-09-11, sin pendiente.

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
