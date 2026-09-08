<script setup>
import { computed, ref } from 'vue'
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
      <div v-else class="h-full w-full bg-linear-to-br from-brand-200 to-brand-500" />
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
