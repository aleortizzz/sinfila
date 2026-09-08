import { supabase } from './supabase'

// Crea el pedido a través de la función crear_pedido (ver
// supabase/migrations/20260907160000_crear_pedido.sql). Nunca insertamos
// directo en "pedidos": la función recalcula precios y valida todo del
// lado del servidor, y devuelve { id, numero }.
export async function crearPedido(payload) {
  const { data, error } = await supabase.rpc('crear_pedido', { p_payload: payload })
  if (error) throw new Error(error.message)
  return data // { id, numero }
}

// Mismo cálculo que crear_pedido (precio real + opciones + motor de promos)
// pero sin insertar nada — el checkout lo usa para mostrar el descuento de
// promo antes de pagar. Devuelve { subtotal, descuento_promos, total, items }.
export async function previsualizarPedido(payload) {
  const { data, error } = await supabase.rpc('previsualizar_pedido', { p_payload: payload })
  if (error) throw new Error(error.message)
  return data
}

// --- Pantalla del local (KDS) ---

const SELECT_PEDIDO_CON_ITEMS = '*, pedido_items(*)'

export async function obtenerPedidosActivos(localId) {
  const { data, error } = await supabase
    .from('pedidos')
    .select(SELECT_PEDIDO_CON_ITEMS)
    .eq('local_id', localId)
    .in('estado', ['pendiente', 'en_preparacion', 'listo', 'avisado'])
    .order('numero', { ascending: true })
  if (error) throw error
  return data ?? []
}

export async function obtenerPedidoConItems(pedidoId) {
  const { data, error } = await supabase
    .from('pedidos')
    .select(SELECT_PEDIDO_CON_ITEMS)
    .eq('id', pedidoId)
    .maybeSingle()
  if (error) throw error
  return data
}

export async function actualizarPedido(pedidoId, cambios) {
  const { error } = await supabase.from('pedidos').update(cambios).eq('id', pedidoId)
  if (error) throw new Error(error.message)
}

// Se suscribe a los cambios de "pedidos" de un local. onCambio recibe
// ('insert' | 'update', fila). Devuelve el canal: hay que desuscribirlo
// (supabase.removeChannel(canal)) al desmontar la vista.
export function suscribirseAPedidos(localId, onCambio) {
  return supabase
    .channel(`pedidos-local-${localId}`)
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'pedidos', filter: `local_id=eq.${localId}` },
      (payload) => onCambio('insert', payload.new),
    )
    .on(
      'postgres_changes',
      { event: 'UPDATE', schema: 'public', table: 'pedidos', filter: `local_id=eq.${localId}` },
      (payload) => onCambio('update', payload.new),
    )
    .subscribe()
}

// --- Seguimiento del pedido (cliente sin cuenta) ---

export async function obtenerPedidoPublico(pedidoId) {
  const { data, error } = await supabase.rpc('obtener_pedido_publico', { p_id: pedidoId })
  if (error) throw new Error(error.message)
  return data
}

export async function obtenerZonasDelivery(localId) {
  const { data, error } = await supabase
    .from('zonas_delivery')
    .select('barrio, costo')
    .eq('local_id', localId)
    .order('barrio')
  if (error) throw error
  return data ?? []
}
