import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'

// Carrito con Pinia. Se persiste en localStorage, siempre atado al slug del
// local que se está mirando: si el cliente entra a la carta de OTRO local,
// el carrito anterior no tiene sentido (no se puede pedir a dos locales a
// la vez), así que se vacía solo.
const STORAGE_KEY = 'sinfila_carrito'

function cargarDeStorage() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

function guardarEnStorage(localSlug, items) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ localSlug, items }))
  } catch {
    // localStorage puede fallar (privado, cuota, etc.) — no es crítico acá.
  }
}

// Clave de "línea" del carrito: mismo producto/combo + mismas opciones
// elegidas = se suman cantidades en vez de crear una línea nueva.
function claveLinea(tipo, refId, opciones) {
  const opcionesOrdenadas = [...opciones].map((o) => o.opcionId).sort().join(',')
  return `${tipo}:${refId}:${opcionesOrdenadas}`
}

export const useCartStore = defineStore('cart', () => {
  const localSlug = ref(null)
  const items = ref([]) // ver forma de cada item en agregar()

  // Al cargar la app, si había un carrito guardado, lo restauramos.
  const guardado = cargarDeStorage()
  if (guardado) {
    localSlug.value = guardado.localSlug
    items.value = guardado.items
  }

  watch([localSlug, items], () => guardarEnStorage(localSlug.value, items.value), { deep: true })

  function inicializarParaLocal(slug) {
    if (localSlug.value !== slug) {
      localSlug.value = slug
      items.value = []
    }
  }

  function precioUnitario(item) {
    return item.precioBase + item.opciones.reduce((s, o) => s + o.precioAjuste, 0)
  }

  function agregar({ tipo, refId, nombre, precioBase, estacion, opciones = [], cantidad = 1 }) {
    const clave = claveLinea(tipo, refId, opciones)
    const existente = items.value.find((i) => i.clave === clave)
    if (existente) {
      existente.cantidad += cantidad
      return
    }
    items.value.push({
      id: crypto.randomUUID(),
      clave,
      tipo,
      refId,
      nombre,
      precioBase,
      estacion,
      opciones,
      cantidad,
    })
  }

  function cambiarCantidad(itemId, cantidad) {
    const item = items.value.find((i) => i.id === itemId)
    if (!item) return
    if (cantidad <= 0) {
      quitar(itemId)
      return
    }
    item.cantidad = cantidad
  }

  function quitar(itemId) {
    items.value = items.value.filter((i) => i.id !== itemId)
  }

  function vaciar() {
    items.value = []
  }

  const cantidadTotal = computed(() => items.value.reduce((s, i) => s + i.cantidad, 0))
  const subtotal = computed(() =>
    items.value.reduce((s, i) => s + precioUnitario(i) * i.cantidad, 0),
  )

  return {
    localSlug,
    items,
    cantidadTotal,
    subtotal,
    precioUnitario,
    inicializarParaLocal,
    agregar,
    cambiarCantidad,
    quitar,
    vaciar,
  }
})
