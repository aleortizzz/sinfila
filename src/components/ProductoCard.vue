<script setup>
import { reactive } from 'vue'
import { useCartStore } from '../stores/cart'

const props = defineProps({ producto: { type: Object, required: true } })
const cart = useCartStore()

// Selección actual por grupo de opciones: { [grupoId]: opcionId }.
// Pre-seleccionamos la primera opción de cada grupo obligatorio para no
// tener que bloquear el botón "Agregar" hasta que el cliente elija algo.
const seleccion = reactive({})
for (const g of props.producto.grupos_opciones) {
  if (g.opciones.length) seleccion[g.id] = g.opciones[0].id
}

function opcionesElegidas() {
  return props.producto.grupos_opciones.map((g) => {
    const opcion = g.opciones.find((o) => o.id === seleccion[g.id])
    return {
      grupoId: g.id,
      grupoNombre: g.nombre,
      opcionId: opcion.id,
      opcionNombre: opcion.nombre,
      // Los numeric de Postgres llegan como string por PostgREST (para no
      // perder precisión) — hay que convertirlos antes de sumarlos en JS.
      precioAjuste: Number(opcion.precio_ajuste),
    }
  })
}

function agregar() {
  cart.agregar({
    tipo: 'producto',
    refId: props.producto.id,
    nombre: props.producto.nombre,
    precioBase: Number(props.producto.precio),
    estacion: props.producto.estacion,
    opciones: opcionesElegidas(),
  })
}
</script>

<template>
  <li class="px-4 py-3">
    <div class="flex items-start justify-between gap-3">
      <div>
        <p class="font-medium">{{ producto.nombre }}</p>
        <p v-if="producto.descripcion" class="text-sm text-slate-500">{{ producto.descripcion }}</p>
      </div>
      <span class="whitespace-nowrap font-semibold">${{ producto.precio }}</span>
    </div>

    <div v-for="g in producto.grupos_opciones" :key="g.id" class="mt-2">
      <p class="text-xs text-slate-500">{{ g.nombre }}</p>
      <div class="mt-1 flex flex-wrap gap-2">
        <button
          v-for="o in g.opciones"
          :key="o.id"
          type="button"
          @click="seleccion[g.id] = o.id"
          :class="[
            'rounded-full border px-3 py-1 text-xs transition',
            seleccion[g.id] === o.id
              ? 'border-slate-900 bg-slate-900 text-white'
              : 'border-slate-300 text-slate-600 hover:border-slate-400',
          ]"
        >
          {{ o.nombre }}<span v-if="o.precio_ajuste"> (+${{ o.precio_ajuste }})</span>
        </button>
      </div>
    </div>

    <button
      type="button"
      @click="agregar"
      class="mt-3 rounded-md bg-slate-900 px-3 py-1.5 text-sm font-medium text-white hover:bg-slate-700"
    >
      Agregar
    </button>
  </li>
</template>
