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

export const notificarExito = (mensaje, duracionMs) => notificar('exito', mensaje, duracionMs)
export const notificarError = (mensaje, duracionMs) => notificar('error', mensaje, duracionMs)
export const notificarAdvertencia = (mensaje, duracionMs) => notificar('advertencia', mensaje, duracionMs)
// "info": eventos que le pasan al usuario, no resultado de una acción suya
// (ej. "llegó un pedido nuevo") — mismo look, pero un color propio para no
// confundirlo con "guardaste algo y salió bien".
export const notificarInfo = (mensaje, duracionMs) => notificar('info', mensaje, duracionMs)
