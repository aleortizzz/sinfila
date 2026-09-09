<script setup>
import { computed, reactive, ref } from 'vue'
import { useCartStore } from '../stores/cart'
import { pesos } from '../lib/formato'

const props = defineProps({
  combo: { type: Object, required: true },
  cerrado: { type: Boolean, default: false },
})
const cart = useCartStore()

// Suma de los productos que integran el combo, comprados sueltos — si es
// mayor al precio del combo, se muestra tachada (el ahorro que ve el cliente).
const precioSugerido = computed(() =>
  (props.combo.combo_items ?? []).reduce(
    (s, i) => s + Number(i.productos?.precio ?? 0) * i.cantidad,
    0,
  ),
)
const hayDescuento = computed(() => precioSugerido.value > Number(props.combo.precio))
const ahorro = computed(() => precioSugerido.value - Number(props.combo.precio))

// Partes del combo que tienen variantes para elegir (ej. la gaseosa con
// "Sabor"). Si ninguna tiene, el combo se agrega de una.
const partesConOpciones = computed(() =>
  (props.combo.combo_items ?? [])
    .filter((ci) => (ci.productos?.grupos_opciones ?? []).length > 0)
    .map((ci) => ci.productos),
)

// Selección actual por grupo: { [grupoId]: opcionId | null }.
// Obligatorio → primera opción; opcional → sin elegir.
const seleccion = reactive({})
for (const prod of partesConOpciones.value) {
  for (const g of prod.grupos_opciones) {
    seleccion[g.id] = g.obligatorio && g.opciones.length ? g.opciones[0].id : null
  }
}

function opcionesElegidas() {
  const out = []
  for (const prod of partesConOpciones.value) {
    for (const g of prod.grupos_opciones) {
      const opcion = g.opciones.find((o) => o.id === seleccion[g.id])
      if (!opcion) continue // grupo opcional sin elegir
      out.push({
        grupoId: g.id,
        grupoNombre: g.nombre,
        opcionId: opcion.id,
        opcionNombre: opcion.nombre,
        productoNombre: prod.nombre,
        precioAjuste: 0, // dentro de un combo la variante no ajusta el precio
      })
    }
  }
  return out
}

const agregado = ref(false)
let t = null
function agregar() {
  if (props.cerrado) return
  cart.agregar({
    tipo: 'combo',
    refId: props.combo.id,
    nombre: props.combo.nombre,
    // Los numeric de Postgres llegan como string por PostgREST.
    precioBase: Number(props.combo.precio),
    estacion: props.combo.estacion,
    opciones: opcionesElegidas(),
  })
  agregado.value = true
  clearTimeout(t)
  t = setTimeout(() => (agregado.value = false), 900)
}
</script>

<template>
  <article class="card relative flex flex-col overflow-hidden">
    <div class="aspect-4/3 w-full overflow-hidden bg-slate-100">
      <img
        v-if="combo.foto_url"
        :src="combo.foto_url"
        :alt="combo.nombre"
        class="h-full w-full object-cover"
      />
      <div v-else class="tile-brand-strong h-full w-full" />
    </div>

    <span class="absolute left-3 top-3 rounded-full bg-slate-900 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-white">
      Combo
    </span>
    <span
      v-if="hayDescuento"
      class="absolute right-3 top-3 rounded-full bg-white/95 px-2.5 py-1 text-[11px] font-bold shadow t-brand"
    >
      Ahorrás {{ pesos(ahorro) }}
    </span>

    <div class="flex flex-1 flex-col p-4">
      <h3 class="font-semibold text-slate-900">{{ combo.nombre }}</h3>
      <p v-if="combo.descripcion" class="mt-0.5 line-clamp-2 text-sm text-slate-500">
        {{ combo.descripcion }}
      </p>

      <!-- Variantes: un bloque por producto del combo que tenga para elegir. -->
      <div v-for="prod in partesConOpciones" :key="prod.id" class="mt-3">
        <p class="text-xs font-semibold text-slate-500">{{ prod.nombre }}</p>
        <div v-for="g in prod.grupos_opciones" :key="g.id" class="mt-1.5">
          <p class="text-xs font-medium text-slate-400">{{ g.nombre }}</p>
          <div class="mt-1 flex flex-wrap gap-1.5">
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
                seleccion[g.id] === o.id ? 'chip-active' : 'border-slate-300 text-slate-600 hover:border-slate-400',
              ]"
            >
              {{ o.nombre }}
            </button>
          </div>
        </div>
      </div>

      <div class="mt-auto flex items-center justify-between pt-4">
        <div class="flex items-baseline gap-1.5">
          <span class="text-lg font-extrabold text-slate-900">{{ pesos(combo.precio) }}</span>
          <span v-if="hayDescuento" class="text-xs text-slate-400 line-through">{{ pesos(precioSugerido) }}</span>
        </div>
        <button
          type="button"
          @click="agregar"
          :disabled="cerrado"
          class="add-btn disabled:cursor-not-allowed disabled:opacity-40"
          :aria-label="`Agregar ${combo.nombre}`"
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
