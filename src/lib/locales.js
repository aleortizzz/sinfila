import { supabase } from './supabase'

// Data access de "local": nada reactivo acá, eso lo maneja quien lo consuma
// (Carta.vue, y más adelante el checkout / panel). Funciones puras que
// hablan con Supabase.

export async function obtenerLocalPorSlug(slug) {
  const { data, error } = await supabase
    .from('locales')
    .select(
      `id, nombre, slug, estado, logo_url, color_primario, banner_url,
       horario_apertura, horario_cierre,
       horario_barra_apertura, horario_barra_cierre,
       horario_cocina_apertura, horario_cocina_cierre,
       acepta_retiro, acepta_delivery,
       acepta_efectivo, acepta_transferencia, alias_transferencia, cbu_transferencia,
       delivery_costo_modo, delivery_costo_fijo, delivery_minimo_compra`,
    )
    .eq('slug', slug)
    .maybeSingle()
  if (error) throw error
  return data
}

// ¿El local está abierto ahora? La cuenta (con hora de Argentina y horarios
// que cruzan la medianoche) la hace la función local_abierto() en la base.
export async function estaAbierto(localId) {
  const { data, error } = await supabase.rpc('local_abierto', { p_local_id: localId })
  if (error) throw error
  return data === true
}

// Promos que aplican ahora mismo (día + franja horaria ya chequeados en la
// base), con el producto al que van. La carta las usa para mostrar el
// precio tachado / la etiqueta de promo.
export async function obtenerPromosVigentes(localId) {
  const { data, error } = await supabase.rpc('promos_vigentes', { p_local_id: localId })
  if (error) throw error
  return (data ?? []).map((r) => ({
    producto_id: r.producto_id,
    tipo: r.tipo,
    precio_especial: r.precio_especial,
    descuento_pct: r.descuento_pct,
    n: r.n,
    m: r.m,
  }))
}

// Los 7 días de horario para mostrar la grilla en la carta.
export async function obtenerHorarios(localId) {
  const { data, error } = await supabase
    .from('horarios_local')
    .select('dia, abierto, apertura, cierre')
    .eq('local_id', localId)
    .order('dia')
  if (error) throw error
  return data ?? []
}

export async function obtenerMenu(localId) {
  const [categoriasRes, productosRes, combosRes] = await Promise.all([
    supabase
      .from('categorias')
      .select('id, nombre, orden')
      .eq('local_id', localId)
      .order('orden'),
    supabase
      .from('productos')
      .select(
        `id, nombre, descripcion, precio, foto_url, categoria_id, estacion, orden,
         grupos_opciones ( id, nombre, obligatorio, orden,
           opciones ( id, nombre, precio_ajuste, orden ) )`,
      )
      .eq('local_id', localId)
      .eq('disponible', true)
      .order('orden'),
    supabase
      .from('combos')
      .select(
        `id, nombre, descripcion, precio, foto_url, estacion, orden,
         combo_items ( cantidad, productos ( precio ) )`,
      )
      .eq('local_id', localId)
      .eq('disponible', true)
      .order('orden'),
  ])
  if (categoriasRes.error) throw categoriasRes.error
  if (productosRes.error) throw productosRes.error
  if (combosRes.error) throw combosRes.error

  // Ordenamos los grupos/opciones anidados (PostgREST no aplica el .order()
  // a las relaciones embebidas, solo a la tabla principal).
  const productos = (productosRes.data ?? []).map((p) => ({
    ...p,
    grupos_opciones: [...(p.grupos_opciones ?? [])]
      .sort((a, b) => a.orden - b.orden)
      .map((g) => ({ ...g, opciones: [...(g.opciones ?? [])].sort((a, b) => a.orden - b.orden) })),
  }))

  return {
    categorias: categoriasRes.data ?? [],
    productos,
    combos: combosRes.data ?? [],
  }
}
