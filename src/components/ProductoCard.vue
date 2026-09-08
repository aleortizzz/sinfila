<script setup>
import { reactive, ref } from 'vue'
import { useCartStore } from '../stores/cart'
import { pesos } from '../lib/formato'

const props = defineProps({
  producto: { type: Object, required: true },
  // Mejor promo vigente para este producto: { tipo, precioPromo, etiqueta, ahorro }.
  promo: { type: Object, default: null },
  // Local cerrado: se puede mirar pero no agregar.
  cerrado: { type: Boolean, default: false },
})
const cart = useCartStore()

// Selección actual por grupo de opciones: { [grupoId]: opcionId | null }.
// Grupo obligatorio → primera opción marcada. Grupo opcional → arranca sin
// elegir (el cliente puede dejar "Ninguna").
const seleccion = reactive({})
for (const g of props.producto.grupos_opciones) {
  seleccion[g.id] = g.obligatorio && g.opciones.length ? g.opciones[0].id : null
}

function opcionesElegidas() {
  return props.producto.grupos_opciones
    .map((g) => {
      const opcion = g.opciones.find((o) => o.id === seleccion[g.id])
      if (!opcion) return null // grupo opcional que quedó en "Ninguna"
      return {
        grupoId: g.id,
        grupoNombre: g.nombre,
        opcionId: opcion.id,
        opcionNombre: opcion.nombre,
        // Los numeric de Postgres llegan como string por PostgREST — convertir.
        precioAjuste: Number(opcion.precio_ajuste),
      }
    })
    .filter(Boolean)
}

// Feedback visual: el botón "+" muestra un ✓ un instante al agregar.
const agregado = ref(false)
let t = null
function agregar() {
  if (props.cerrado) return
  cart.agregar({
    tipo: 'producto',
    refId: props.producto.id,
    nombre: props.producto.nombre,
    precioBase: Number(props.producto.precio),
    estacion: props.producto.estacion,
    opciones: opcionesElegidas(),
  })
  agregado.value = true
  clearTimeout(t)
  t = setTimeout(() => (agregado.value = false), 900)
}
</script>

<template>
  <article class="card relative flex flex-col overflow-hidden">
    <span
      v-if="promo"
      class="bg-brand absolute left-3 top-3 z-10 rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-white shadow"
    >
      {{ promo.etiqueta || 'Promo' }}
    </span>

    <div class="aspect-4/3 w-full overflow-hidden bg-slate-100">
      <img
        v-if="producto.foto_url"
        :src="producto.foto_url"
        :alt="producto.nombre"
        class="h-full w-full object-cover"
      />
      <div v-else class="tile-brand flex h-full w-full items-center justify-center">
        <svg viewBox="0 0 24 24" fill="none" class="icon-brand-ghost h-10 w-10">
          <path
            d="M6 3h12l-1.2 16.2A2 2 0 0 1 14.8 21H9.2a2 2 0 0 1-2-1.8L6 3Z"
            stroke="currentColor"
            stroke-width="1.4"
            stroke-linejoin="round"
          />
          <path d="M6.6 9h10.8" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" />
        </svg>
      </div>
    </div>

    <div class="flex flex-1 flex-col p-4">
      <h3 class="font-semibold text-slate-900">{{ producto.nombre }}</h3>
      <p v-if="producto.descripcion" class="mt-0.5 line-clamp-2 text-sm text-slate-500">
        {{ producto.descripcion }}
      </p>

      <div v-for="g in producto.grupos_opciones" :key="g.id" class="mt-3">
        <p class="text-xs font-medium text-slate-400">{{ g.nombre }}</p>
        <div class="mt-1.5 flex flex-wrap gap-1.5">
          <button
            v-if="!g.obligatorio"
            type="button"
            @click="seleccion[g.id] = null"
            :class="[
              'rounded-full border px-2.5 py-1 text-xs font-medium transition',
              seleccion[g.id] == null ? 'chip-active' : 'border-slate-300 text-slate-600 hover:border-slate-400',
            ]"
          >
            Ninguna
          </button>
          <button
            v-for="o in g.opciones"
            :key="o.id"
            type="button"
            @click="seleccion[g.id] = o.id"
            :class="[
              'rounded-full border px-2.5 py-1 text-xs font-medium transition',
              seleccion[g.id] === o.id
                ? 'chip-active'
                : 'border-slate-300 text-slate-600 hover:border-slate-400',
            ]"
          >
            {{ o.nombre }}<span v-if="o.precio_ajuste" class="opacity-70"> +{{ pesos(o.precio_ajuste) }}</span>
          </button>
        </div>
      </div>

      <div class="mt-auto flex items-center justify-between pt-4">
        <div class="flex items-baseline gap-1.5">
          <span
            v-if="promo && promo.precioPromo < Number(producto.precio)"
            class="text-lg font-extrabold t-brand"
          >
            {{ pesos(promo.precioPromo) }}
          </span>
          <span
            :class="
              promo && promo.precioPromo < Number(producto.precio)
                ? 'text-xs text-slate-400 line-through'
                : 'text-lg font-extrabold text-slate-900'
            "
          >
            {{ pesos(producto.precio) }}
          </span>
        </div>
        <button
          type="button"
          @click="agregar"
          :disabled="cerrado"
          class="add-btn disabled:cursor-not-allowed disabled:opacity-40"
          :aria-label="`Agregar ${producto.nombre}`"
        >
          <svg v-if="!agregado" viewBox="0 0 24 24" class="h-5 w-5" fill="none" stroke="currentColor" stroke-width="2.5">
            <path d="M12 5v14M5 12h14" stroke-linecap="round" />
          </svg>
          <svg v-else viewBox="0 0 24 24" class="h-5 w-5" fill="none" stroke="currentColor" stroke-width="2.5">
            <path d="M5 13l4 4L19 7" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </button>
      </div>
    </div>
  </article>
</template>
