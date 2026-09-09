import { supabase } from './supabase'

// Traduce los mensajes de error de Supabase/PostgREST (en inglés) a algo
// legible en español. Los que necesitan distinguirse en la UI llevan .code.
const TRADUCCIONES = [
  { re: /email not confirmed/i, code: 'email_no_verificado', txt: 'Todavía no verificaste tu mail. Revisá tu casilla.' },
  { re: /invalid login credentials/i, txt: 'Email o contraseña incorrectos.' },
  { re: /email address .* is invalid|invalid format|unable to validate email/i, txt: 'Ese email no es válido.' },
  { re: /user already registered|already.*registered/i, txt: 'Ya existe una cuenta con ese email.' },
  { re: /password should be at least (\d+)/i, txt: (m) => `La contraseña tiene que tener al menos ${m[1]} caracteres.` },
  { re: /weak password|password is too weak/i, txt: 'La contraseña es muy débil, probá con una más larga.' },
  { re: /for security purposes, you can only request this after (\d+)/i, txt: (m) => `Esperá ${m[1]} segundos antes de volver a pedirlo.` },
  { re: /email rate limit|over_email_send_rate|too many requests|rate limit/i, txt: 'Demasiados intentos. Probá de nuevo en un rato.' },
  { re: /signups? (not allowed|disabled)/i, txt: 'El registro está deshabilitado por el momento.' },
  { re: /failed to fetch|network ?error|networkerror/i, txt: 'Problema de conexión. Revisá tu internet e intentá de nuevo.' },
]

function esp(error) {
  const msg = error?.message || String(error ?? 'Error desconocido')
  for (const t of TRADUCCIONES) {
    const m = msg.match(t.re)
    if (m) {
      const e = new Error(typeof t.txt === 'function' ? t.txt(m) : t.txt)
      if (t.code) e.code = t.code
      return e
    }
  }
  return new Error(msg)
}

export async function iniciarSesion(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw esp(error)
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
  if (error) throw esp(error)
  return data // { user, session } — session es null si el proyecto exige confirmar el mail
}

export async function reenviarVerificacion(email) {
  const { error } = await supabase.auth.resend({ type: 'signup', email })
  if (error) throw esp(error)
}

export async function pedirResetContrasena(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
    redirectTo: `${window.location.origin}/nueva-contrasena`,
  })
  if (error) throw esp(error)
}

// Se llama estando en la sesión temporal de recuperación (tras el enlace).
export async function cambiarContrasena(nueva) {
  const { error } = await supabase.auth.updateUser({ password: nueva })
  if (error) throw esp(error)
}

// --- Onboarding / super-admin ---

// Crea negocio + local (pendiente_activacion) + rol de dueño para el usuario
// logueado. Devuelve el slug. En el MVP negocio y local se llaman igual
// (single-local); el esquema los separa para multi-sucursal a futuro.
export async function registrarNegocio(nombre, slug) {
  const { data, error } = await supabase.rpc('registrar_negocio', {
    p_nombre_negocio: nombre,
    p_nombre_local: nombre,
    p_slug: slug,
  })
  if (error) throw esp(error)
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
  if (error) throw esp(error)
  return data
}

export async function listarLocalesSuperadmin() {
  const { data, error } = await supabase.rpc('listar_locales_superadmin')
  if (error) throw esp(error)
  return data ?? []
}

export async function activarLocal(localId, precioMensual) {
  const { error } = await supabase.rpc('activar_local', {
    p_local_id: localId,
    p_precio_mensual: Number(precioMensual) || 0,
  })
  if (error) throw esp(error)
}

export async function registrarPago(localId, monto, metodo = 'transferencia') {
  const { error } = await supabase.rpc('registrar_pago', {
    p_local_id: localId,
    p_monto: Number(monto) || 0,
    p_metodo: metodo,
  })
  if (error) throw esp(error)
}

export async function suspenderLocal(localId) {
  const { error } = await supabase.rpc('suspender_local', { p_local_id: localId })
  if (error) throw esp(error)
}
