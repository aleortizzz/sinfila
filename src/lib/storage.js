import { supabase } from './supabase'

const BUCKET = 'imagenes'
const MAX_BYTES = 5 * 1024 * 1024

// Sube una imagen y devuelve su URL pública.
//   carpeta: 'locales' | 'productos'
//   El path queda <carpeta>/<localId>/<prefijo>-<timestamp>.<ext>, así el
//   2º segmento (localId) es lo que la policy de Storage usa para permitir
//   la escritura al dueño.
export async function subirImagen(carpeta, localId, archivo, prefijo) {
  if (!archivo.type?.startsWith('image/')) {
    throw new Error('El archivo tiene que ser una imagen.')
  }
  if (archivo.size > MAX_BYTES) {
    throw new Error('La imagen no puede pesar más de 5 MB.')
  }
  const ext = (archivo.name.split('.').pop() || 'png').toLowerCase().replace(/[^a-z0-9]/g, '')
  const path = `${carpeta}/${localId}/${prefijo}-${Date.now()}.${ext}`
  const { error } = await supabase.storage.from(BUCKET).upload(path, archivo, {
    cacheControl: '3600',
    upsert: true,
  })
  if (error) throw new Error(error.message)
  return supabase.storage.from(BUCKET).getPublicUrl(path).data.publicUrl
}
