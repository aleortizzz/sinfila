import { reactive } from 'vue'

// Sistema de toasts genérico y chico a propósito — sin Pinia, es un array
// reactivo compartido. Pensado para reusarse en cualquier pantalla que
// haga guardado automático (sin botón "Guardar") y necesite confirmar que
// algo pasó de verdad.
export const toasts = reactive([])

let siguienteId = 0

// `opciones.ruta`: si se pasa, el toast se puede clickear y navega ahí
// (ToastStack la usa con el router) — pensado para notificaciones tipo
// "nuevo pedido" que tienen una pantalla obvia a la que ir.
export function notificar(tipo, mensaje, opciones = {}) {
  const { duracionMs = 3000, ruta = null } = opciones
  const id = ++siguienteId
  toasts.push({ id, tipo, mensaje, ruta })
  setTimeout(() => {
    const i = toasts.findIndex((t) => t.id === id)
    if (i !== -1) toasts.splice(i, 1)
  }, duracionMs)
  return id
}

export const notificarExito = (mensaje, opciones) => notificar('exito', mensaje, opciones)
export const notificarError = (mensaje, opciones) => notificar('error', mensaje, opciones)
export const notificarAdvertencia = (mensaje, opciones) => notificar('advertencia', mensaje, opciones)
// "info": eventos que le pasan al usuario, no resultado de una acción suya
// (ej. "llegó un pedido nuevo") — mismo look, pero un color propio para no
// confundirlo con "guardaste algo y salió bien".
export const notificarInfo = (mensaje, opciones) => notificar('info', mensaje, opciones)
