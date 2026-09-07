import { createClient } from '@supabase/supabase-js'

// Las credenciales vienen de variables de entorno (.env), nunca hardcodeadas.
// Vite solo expone al navegador las variables que empiezan con VITE_.
export const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL
export const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY

// true solo si el .env está completo.
export const supabaseConfigured = Boolean(SUPABASE_URL && SUPABASE_ANON_KEY)

if (!supabaseConfigured) {
  console.warn(
    '[supabase] Faltan VITE_SUPABASE_URL o VITE_SUPABASE_ANON_KEY en el archivo .env',
  )
}

// Si falta el .env usamos valores dummy para que createClient no tire un error
// que rompa toda la app; el chequeo de conexión en App.vue avisa qué falta.
export const supabase = createClient(
  SUPABASE_URL || 'http://localhost:54321',
  SUPABASE_ANON_KEY || 'anon-key-placeholder',
)
