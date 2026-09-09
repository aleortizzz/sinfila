import { supabase } from './supabase'

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

// dias: 7 / 30 / 90, o 0 = desde que se creó el local.
export async function obtenerReporte(localId, dias = 30) {
  const { data, error } = await supabase.rpc('reporte_local', { p_local_id: localId, p_dias: dias })
  if (error) throw error
  return data // { serie:[{fecha,pedidos,ventas}], top:[{nombre,unidades,monto}], recientes:[...] } | null
}

// Más vendidos de un rango (para filtrar por el día clickeado en el gráfico).
export async function obtenerTopProductos(localId, desde, hasta) {
  const { data, error } = await supabase.rpc('top_productos_local', {
    p_local_id: localId,
    p_desde: desde,
    p_hasta: hasta,
  })
  if (error) throw error
  return data ?? []
}

export async function obtenerDetallePedido(pedidoId) {
  const { data, error } = await supabase.rpc('pedido_detalle', { p_pedido_id: pedidoId })
  if (error) throw error
  return data
}

export async function obtenerHistorial(localId, { dias = 30, estado = null, limit = 50, offset = 0 } = {}) {
  const { data, error } = await supabase.rpc('historial_pedidos', {
    p_local_id: localId,
    p_dias: dias,
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
