import { supabase, crearClienteAislado } from './supabase'
import { esp } from './auth'

// Conserva error.code (ej. '23503' foreign key) — así el que llama puede
// distinguir "está referenciado en otro lado" de cualquier otro error, en
// vez de adivinar por el texto del mensaje.
function lanzar(error) {
  const e = new Error(error.message)
  e.code = error.code
  throw e
}

// Data access para el panel admin. A diferencia de lib/locales.js (que
// filtra disponible=true para la carta pública), acá se ve TODO — el
// dueño necesita administrar lo que está oculto también.

// --- Estadísticas del inicio (solo dueño) ---
export async function obtenerEstadisticas(localId) {
  const { data, error } = await supabase.rpc('estadisticas_local', { p_local_id: localId })
  if (error) throw error
  return data // { pedidos_hoy, ventas_hoy, pedidos_7d, ventas_7d, ventas_mes, productos_activos } | null
}

// rango: { desde, hasta, prevDesde, prevHasta } — ver lib/periodos.js.
// categoriaId: null = todo el local; con id = solo ítems de esa categoría.
export async function obtenerReporte(
  localId,
  {
    desde = null,
    hasta = null,
    prevDesde = null,
    prevHasta = null,
    categoriaId = null,
    incluirEnvio = true,
  } = {},
) {
  const { data, error } = await supabase.rpc('reporte_local', {
    p_local_id: localId,
    p_desde: desde,
    p_hasta: hasta,
    p_prev_desde: prevDesde,
    p_prev_hasta: prevHasta,
    p_categoria_id: categoriaId,
    p_incluir_envio: incluirEnvio,
  })
  if (error) throw error
  return data // { desde, hasta, serie, top, resumen, previo } | null
}

// Pedidos manejados y tiempo de preparación por persona + tiempo general
// del local. Usa pedido_estados.changed_by, que ya se graba desde siempre.
export async function obtenerReporteProductividad(localId, { desde = null, hasta = null } = {}) {
  const { data, error } = await supabase.rpc('reporte_productividad', {
    p_local_id: localId,
    p_desde: desde,
    p_hasta: hasta,
  })
  if (error) throw error
  return data // { desde, hasta, general: {...}, por_persona: [...] } | null
}

// Más vendidos de un rango (para filtrar por el día clickeado en el gráfico).
export async function obtenerTopProductos(localId, desde, hasta, categoriaId = null) {
  const { data, error } = await supabase.rpc('top_productos_local', {
    p_local_id: localId,
    p_desde: desde,
    p_hasta: hasta,
    p_categoria_id: categoriaId,
  })
  if (error) throw error
  return data ?? []
}

export async function obtenerDetallePedido(pedidoId) {
  const { data, error } = await supabase.rpc('pedido_detalle', { p_pedido_id: pedidoId })
  if (error) throw error
  return data
}

export async function obtenerHistorial(
  localId,
  { desde = null, hasta = null, estado = null, limit = 50, offset = 0 } = {},
) {
  const { data, error } = await supabase.rpc('historial_pedidos', {
    p_local_id: localId,
    p_desde: desde,
    p_hasta: hasta,
    p_estado: estado,
    p_limit: limit,
    p_offset: offset,
  })
  if (error) throw error
  return data ?? { total: 0, pedidos: [] }
}

// --- Config del local ---
// El dueño tiene UPDATE columna por columna sobre "locales" (ver los GRANT
// en la migración base): puede tocar nombre/horarios/branding/pago/delivery
// pero NO estado/trial_hasta. Si intenta colar una de esas, Postgres tira
// "permission denied for column" y lo vemos acá.

export async function actualizarLocal(id, cambios) {
  const { error } = await supabase.from('locales').update(cambios).eq('id', id)
  if (error) lanzar(error)
}

export async function obtenerHorariosAdmin(localId) {
  const { data, error } = await supabase
    .from('horarios_local')
    .select('dia, abierto, apertura, cierre')
    .eq('local_id', localId)
    .order('dia')
  if (error) throw error
  return data ?? []
}

export async function actualizarHorarioDia(localId, dia, cambios) {
  const { error } = await supabase
    .from('horarios_local')
    .update(cambios)
    .eq('local_id', localId)
    .eq('dia', dia)
  if (error) lanzar(error)
}

export async function obtenerZonasAdmin(localId) {
  const { data, error } = await supabase
    .from('zonas_delivery')
    .select('id, barrio, costo')
    .eq('local_id', localId)
    .order('barrio')
  if (error) throw error
  return data ?? []
}

export async function crearZona(localId, barrio, costo) {
  const { data, error } = await supabase
    .from('zonas_delivery')
    .insert({ local_id: localId, barrio, costo })
    .select('id, barrio, costo')
    .single()
  if (error) lanzar(error)
  return data
}

export async function actualizarZona(id, cambios) {
  const { error } = await supabase.from('zonas_delivery').update(cambios).eq('id', id)
  if (error) lanzar(error)
}

export async function eliminarZona(id) {
  const { error } = await supabase.from('zonas_delivery').delete().eq('id', id)
  if (error) lanzar(error)
}

export async function obtenerCategoriasAdmin(localId) {
  const { data, error } = await supabase
    .from('categorias')
    .select('*')
    .eq('local_id', localId)
    .order('orden')
  if (error) throw error
  return data ?? []
}

export async function crearCategoria(localId, nombre, orden = 0) {
  const { data, error } = await supabase
    .from('categorias')
    .insert({ local_id: localId, nombre, orden })
    .select()
    .single()
  if (error) lanzar(error)
  return data
}

export async function actualizarCategoria(id, cambios) {
  const { error } = await supabase.from('categorias').update(cambios).eq('id', id)
  if (error) lanzar(error)
}

export async function eliminarCategoria(id) {
  const { error } = await supabase.from('categorias').delete().eq('id', id)
  if (error) lanzar(error)
}

export async function obtenerProductosAdmin(localId) {
  const { data, error } = await supabase
    .from('productos')
    .select(
      `*, grupos_opciones ( id, nombre, obligatorio, orden,
         opciones ( id, nombre, precio_ajuste, orden ) )`,
    )
    .eq('local_id', localId)
    .order('orden')
  if (error) throw error
  return data ?? []
}

export async function obtenerProductoAdmin(id) {
  const { data, error } = await supabase
    .from('productos')
    .select(
      `*, grupos_opciones ( id, nombre, obligatorio, orden,
         opciones ( id, nombre, precio_ajuste, orden, disponible ) )`,
    )
    .eq('id', id)
    .single()
  if (error) lanzar(error)
  // PostgREST no ordena las relaciones anidadas.
  data.grupos_opciones = [...(data.grupos_opciones ?? [])]
    .sort((a, b) => a.orden - b.orden)
    .map((g) => ({ ...g, opciones: [...(g.opciones ?? [])].sort((a, b) => a.orden - b.orden) }))
  return data
}

export async function crearProducto(payload) {
  const { data, error } = await supabase.from('productos').insert(payload).select().single()
  if (error) lanzar(error)
  return data
}

export async function actualizarProducto(id, cambios) {
  const { error } = await supabase.from('productos').update(cambios).eq('id', id)
  if (error) lanzar(error)
}

export async function eliminarProducto(id) {
  const { error } = await supabase.from('productos').delete().eq('id', id)
  if (error) lanzar(error)
}

// --- Grupos de opciones / opciones (armado de un producto) ---

export async function crearGrupoOpciones(productoId, nombre, obligatorio, orden) {
  const { data, error } = await supabase
    .from('grupos_opciones')
    .insert({ producto_id: productoId, nombre, obligatorio, orden })
    .select()
    .single()
  if (error) lanzar(error)
  return { ...data, opciones: [] }
}

export async function actualizarGrupoOpciones(id, cambios) {
  const { error } = await supabase.from('grupos_opciones').update(cambios).eq('id', id)
  if (error) lanzar(error)
}

export async function eliminarGrupoOpciones(id) {
  const { error } = await supabase.from('grupos_opciones').delete().eq('id', id)
  if (error) lanzar(error)
}

export async function crearOpcion(grupoId, nombre, precioAjuste, orden) {
  const { data, error } = await supabase
    .from('opciones')
    .insert({ grupo_opcion_id: grupoId, nombre, precio_ajuste: precioAjuste, orden })
    .select()
    .single()
  if (error) lanzar(error)
  return data
}

export async function actualizarOpcion(id, cambios) {
  const { error } = await supabase.from('opciones').update(cambios).eq('id', id)
  if (error) lanzar(error)
}

export async function eliminarOpcion(id) {
  const { error } = await supabase.from('opciones').delete().eq('id', id)
  if (error) lanzar(error)
}

// --- Combos ---

export async function obtenerCombosAdmin(localId) {
  const { data, error } = await supabase
    .from('combos')
    .select('*, combo_items ( id, cantidad, producto_id, productos ( nombre ) )')
    .eq('local_id', localId)
    .order('orden')
  if (error) throw error
  return data ?? []
}

export async function obtenerComboAdmin(id) {
  const { data, error } = await supabase
    .from('combos')
    .select('*, combo_items ( id, cantidad, producto_id, productos ( nombre, precio ) )')
    .eq('id', id)
    .single()
  if (error) lanzar(error)
  return data
}

export async function crearCombo(payload) {
  const { data, error } = await supabase.from('combos').insert(payload).select().single()
  if (error) lanzar(error)
  return { ...data, combo_items: [] }
}

export async function actualizarCombo(id, cambios) {
  const { error } = await supabase.from('combos').update(cambios).eq('id', id)
  if (error) lanzar(error)
}

export async function eliminarCombo(id) {
  const { error } = await supabase.from('combos').delete().eq('id', id)
  if (error) lanzar(error)
}

export async function agregarItemCombo(comboId, productoId, cantidad) {
  const { data, error } = await supabase
    .from('combo_items')
    .insert({ combo_id: comboId, producto_id: productoId, cantidad })
    .select('id, cantidad, producto_id, productos ( nombre )')
    .single()
  if (error) lanzar(error)
  return data
}

export async function quitarItemCombo(comboItemId) {
  const { error } = await supabase.from('combo_items').delete().eq('id', comboItemId)
  if (error) lanzar(error)
}

// --- Promos ---

export async function obtenerPromosAdmin(localId) {
  const { data, error } = await supabase
    .from('promos')
    .select('*, promo_productos ( producto_id, productos ( nombre ) )')
    .eq('local_id', localId)
    .order('created_at')
  if (error) throw error
  return data ?? []
}

export async function obtenerPromoAdmin(id) {
  const { data, error } = await supabase
    .from('promos')
    .select('*, promo_productos ( producto_id )')
    .eq('id', id)
    .single()
  if (error) lanzar(error)
  return data
}

export async function crearPromo(payload, productoIds) {
  const { data, error } = await supabase.from('promos').insert(payload).select().single()
  if (error) lanzar(error)
  if (productoIds.length) {
    const { error: errItems } = await supabase
      .from('promo_productos')
      .insert(productoIds.map((producto_id) => ({ promo_id: data.id, producto_id })))
    if (errItems) lanzar(errItems)
  }
  return data
}

export async function actualizarPromo(id, cambios) {
  const { error } = await supabase.from('promos').update(cambios).eq('id', id)
  if (error) lanzar(error)
}

export async function eliminarPromo(id) {
  const { error } = await supabase.from('promos').delete().eq('id', id)
  if (error) lanzar(error)
}

export async function agregarProductoPromo(promoId, productoId) {
  const { error } = await supabase.from('promo_productos').insert({ promo_id: promoId, producto_id: productoId })
  if (error) lanzar(error)
}

export async function quitarProductoPromo(promoId, productoId) {
  const { error } = await supabase
    .from('promo_productos')
    .delete()
    .eq('promo_id', promoId)
    .eq('producto_id', productoId)
  if (error) lanzar(error)
}

// --- Equipo (staff): alta/baja de cuentas, sin tocar SQL a mano ---

export async function obtenerEquipoLocal(localId) {
  const { data, error } = await supabase.rpc('listar_equipo_local', { p_local_id: localId })
  if (error) throw esp(error)
  return data ?? []
}

// Genera una contraseña legible para pasar por WhatsApp — sin caracteres
// que se confunden al leerla en voz alta o transcribirla (0/O, 1/l/I).
export function generarContraseña() {
  const alfabeto = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'
  const bytes = crypto.getRandomValues(new Uint32Array(10))
  return Array.from(bytes, (b) => alfabeto[b % alfabeto.length]).join('')
}

// Los 5 niveles de acceso (ver PROGRESO.md, 2026-09-14). Un solo lugar que
// los define — la UI arma el selector desde acá, nunca hardcodea la lista.
// "dueño" no está acá a propósito: es el único, se crea con
// registrar_negocio(), nunca se asigna desde esta pantalla ni se puede
// tocar (hay un trigger en la base que lo protege).
// El orden de las claves es el orden en que se muestran en el desplegable
// de detalle de cada nivel (ver AdminEquipo.vue).
export const CAPACIDADES = {
  pedidos: 'Panel de pedidos (KDS)',
  facturacion: 'Facturación / reportes',
  menu: 'Menú',
  equipo: 'Equipo',
  config: 'Configuración',
}

export const NIVELES_EQUIPO = [
  {
    valor: 'staff',
    label: 'Staff',
    descripcion: 'Para quienes solo preparan y entregan pedidos.',
    capacidades: { pedidos: true, facturacion: false, menu: false, equipo: false, config: false },
  },
  {
    valor: 'cajero',
    label: 'Cajero',
    descripcion: 'Para quienes además cierran caja y necesitan ver la facturación del día.',
    capacidades: { pedidos: true, facturacion: true, menu: false, equipo: false, config: false },
  },
  {
    valor: 'menu',
    label: 'Menú',
    descripcion: 'Para quienes cargan productos, combos y promociones.',
    capacidades: { pedidos: true, facturacion: false, menu: true, equipo: false, config: false },
  },
  {
    valor: 'encargado',
    label: 'Encargado',
    descripcion: 'Para quienes supervisan todas las tareas: cierran caja y manejan el menú.',
    capacidades: { pedidos: true, facturacion: true, menu: true, equipo: false, config: false },
  },
  {
    valor: 'administrador',
    label: 'Administrador',
    descripcion: 'Para gestionar la configuración del local y los roles del equipo — incluye todos los permisos anteriores.',
    capacidades: { pedidos: true, facturacion: true, menu: true, equipo: true, config: true },
  },
]

function datosDeNivel(nivel) {
  if (nivel === 'administrador') return { rol: 'administrador', ve_facturacion: true, edita_menu: true }
  return {
    rol: 'staff',
    ve_facturacion: nivel === 'cajero' || nivel === 'encargado',
    edita_menu: nivel === 'menu' || nivel === 'encargado',
  }
}

// A la inversa: de una fila de usuario_local_roles a su nivel. Para mostrar
// la selección actual de alguien ya creado.
export function nivelDeFila(m) {
  if (m.rol === 'dueño') return 'dueño'
  if (m.rol === 'administrador') return 'administrador'
  if (m.ve_facturacion && m.edita_menu) return 'encargado'
  if (m.ve_facturacion) return 'cajero'
  if (m.edita_menu) return 'menu'
  return 'staff'
}

// Crea la cuenta de auth del empleado (en un cliente aparte, para no pisar
// la sesión del dueño logueado) y le asigna el nivel elegido en el local.
// El empleado va a tener que confirmar su mail antes de poder loguearse
// (mismo flujo que /registro) — se le pasa el mail + esta contraseña.
//
// Devuelve { usuarioId, yaExistia }. Si el mail ya tenía una cuenta (típico:
// se la había "Quitado" del equipo antes — Quitar nunca borra la cuenta de
// auth, a propósito, justo para este caso), la re-suma usando
// sumar_usuario_existente() en vez de fallar — no se le puede asignar una
// contraseña nueva ahí (no pasa por signUp), así que el caller no debería
// mostrarle una como si fuera nueva.
export async function crearCuentaStaff(localId, email, password, nivel, { nombre = '', telefono = '' } = {}) {
  const emailLimpio = email.trim()
  const datos = datosDeNivel(nivel)
  const cliente = crearClienteAislado()
  const { data, error } = await cliente.auth.signUp({ email: emailLimpio, password })
  if (error) throw esp(error)

  // Mail ya registrado: Supabase no tira error (por seguridad, para no
  // confirmar por enumeración si un mail existe), pero devuelve un user
  // sin identidades nuevas.
  if (!data.user || data.user.identities?.length === 0) {
    const { data: usuarioId, error: errExistente } = await supabase.rpc('sumar_usuario_existente', {
      p_local_id: localId,
      p_email: emailLimpio,
      p_rol: datos.rol,
      p_ve_facturacion: datos.ve_facturacion,
      p_edita_menu: datos.edita_menu,
      p_nombre: nombre.trim() || null,
      p_telefono: telefono.trim() || null,
    })
    if (errExistente) throw esp(errExistente)
    return { usuarioId, yaExistia: true }
  }

  const { error: errRol } = await supabase.from('usuario_local_roles').insert({
    usuario_id: data.user.id,
    local_id: localId,
    ...datos,
    debe_cambiar_password: true,
    nombre: nombre.trim() || null,
    telefono: telefono.trim() || null,
  })
  if (errRol) lanzar(errRol)
  return { usuarioId: data.user.id, yaExistia: false }
}

// Ficha de empleado: nombre/teléfono/notas. Nunca toca la fila del dueño
// (protegida además por el trigger en la base).
// A diferencia de cambiarNivelEquipo/quitarDeEquipo, acá SÍ se puede tocar
// la fila del dueño — nombre/teléfono/notas no son campos sensibles (el
// trigger de la base solo protege `rol`, esto ni lo intenta tocar).
export async function actualizarFichaEquipo(localId, usuarioId, { nombre, telefono, notas }) {
  const { error } = await supabase
    .from('usuario_local_roles')
    .update({ nombre: nombre?.trim() || null, telefono: telefono?.trim() || null, notas: notas?.trim() || null })
    .eq('local_id', localId)
    .eq('usuario_id', usuarioId)
  if (error) lanzar(error)
}

// Nunca toca la fila del dueño (la base lo bloquea con un trigger de
// todas formas, pero acá directamente ni se intenta).
export async function cambiarNivelEquipo(localId, usuarioId, nivel) {
  const { error } = await supabase
    .from('usuario_local_roles')
    .update(datosDeNivel(nivel))
    .eq('local_id', localId)
    .eq('usuario_id', usuarioId)
    .neq('rol', 'dueño')
  if (error) lanzar(error)
}

// Staff o administrador — nunca el dueño (protegido también en la base).
export async function quitarDeEquipo(localId, usuarioId) {
  const { error } = await supabase
    .from('usuario_local_roles')
    .delete()
    .eq('local_id', localId)
    .eq('usuario_id', usuarioId)
    .neq('rol', 'dueño')
  if (error) lanzar(error)
}
