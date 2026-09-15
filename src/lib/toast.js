import { reactive } from 'vue'

// Sistema de toasts genérico y chico a propósito — sin Pinia, es un array
// reactivo compartido. Pensado para reusarse en cualquier pantalla que
// haga guardado automático (sin botón "Guardar") y necesite confirmar que
// algo pasó de verdad.
export const toasts = reactive([])

let siguienteId = 0

export function notificar(tipo, mensaje, duracionMs = 3000) {
  const id = ++siguienteId
  toasts.push({ id, tipo, mensaje })
  setTimeout(() => {
    const i = toasts.findIndex((t) => t.id === id)
    if (i !== -1) toasts.splice(i, 1)
  }, duracionMs)
}

export const notificarExito = (mensaje) => notificar('exito', mensaje)
export const notificarError = (mensaje) => notificar('error', mensaje)
export const notificarAdvertencia = (mensaje) => notificar('advertencia', mensaje)
