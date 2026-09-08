import { supabase } from './supabase'

export async function iniciarSesion(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw new Error(error.message)
  return data
}

export async function cerrarSesion() {
  await supabase.auth.signOut()
}

export async function obtenerSesion() {
  const { data } = await supabase.auth.getSession()
  return data.session
}

export async function registrarUsuario(email, password) {
  const { data, error } = await supabase.auth.signUp({ email, password })
  if (error) throw new Error(error.message)
  return data // { user, session } — session es null si el proyecto exige confirmar el mail
}

// --- Onboarding / super-admin ---

// Crea negocio + local (pendiente_activacion) + rol de dueño para el usuario
// logueado. Devuelve el slug.
export async function registrarNegocio(nombreNegocio, nombreLocal, slug) {
  const { data, error } = await supabase.rpc('registrar_negocio', {
    p_nombre_negocio: nombreNegocio,
    p_nombre_local: nombreLocal,
    p_slug: slug,
  })
  if (error) throw new Error(error.message)
  return data
}

export async function soySuperAdmin() {
  const { data, error } = await supabase.rpc('es_super_admin')
  if (error) return false
  return data === true
}

// El local del usuario logueado (si es dueño/staff de alguno). null si no tiene.
export async function miLocal() {
  const { data, error } = await supabase
    .from('usuario_local_roles')
    .select('rol, locales ( slug, nombre, estado )')
    .limit(1)
    .maybeSingle()
  if (error) throw new Error(error.message)
  return data
}

export async function listarLocalesSuperadmin() {
  const { data, error } = await supabase.rpc('listar_locales_superadmin')
  if (error) throw new Error(error.message)
  return data ?? []
}

export async function activarLocal(localId, precioMensual) {
  const { error } = await supabase.rpc('activar_local', {
    p_local_id: localId,
    p_precio_mensual: Number(precioMensual) || 0,
  })
  if (error) throw new Error(error.message)
}

export async function registrarPago(localId, monto, metodo = 'transferencia') {
  const { error } = await supabase.rpc('registrar_pago', {
    p_local_id: localId,
    p_monto: Number(monto) || 0,
    p_metodo: metodo,
  })
  if (error) throw new Error(error.message)
}
