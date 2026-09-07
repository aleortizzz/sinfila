import { supabase } from './supabase'

// Data access de "local": nada reactivo acá, eso lo maneja quien lo consuma
// (Carta.vue, y más adelante el checkout / panel). Funciones puras que
// hablan con Supabase.

export async function obtenerLocalPorSlug(slug) {
  const { data, error } = await supabase
    .from('locales')
    .select(
      `id, nombre, slug, estado, logo_url, color_primario, banner_url,
       acepta_retiro, acepta_delivery,
       acepta_efectivo, acepta_transferencia, alias_transferencia, cbu_transferencia,
       delivery_costo_modo, delivery_costo_fijo, delivery_minimo_compra`,
    )
    .eq('slug', slug)
    .maybeSingle()
  if (error) throw error
  return data
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
