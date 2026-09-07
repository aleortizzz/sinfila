<script setup>
import { computed } from 'vue'
import { useCartStore } from '../stores/cart'

const props = defineProps({ combo: { type: Object, required: true } })
const cart = useCartStore()

// Suma de los productos que integran el combo, comprados sueltos — si es
// mayor al precio del combo, se lo muestra tachado al lado (el ahorro que
// ve el cliente).
const precioSugerido = computed(() =>
  (props.combo.combo_items ?? []).reduce(
    (s, i) => s + Number(i.productos?.precio ?? 0) * i.cantidad,
    0,
  ),
)
const hayDescuento = computed(() => precioSugerido.value > Number(props.combo.precio))

function agregar() {
  cart.agregar({
    tipo: 'combo',
    refId: props.combo.id,
    nombre: props.combo.nombre,
    // Los numeric de Postgres llegan como string por PostgREST.
    precioBase: Number(props.combo.precio),
    estacion: props.combo.estacion,
  })
}
</script>

<template>
  <li class="flex items-center justify-between gap-3 px-4 py-3">
    <div>
      <p class="font-medium">{{ combo.nombre }}</p>
      <p v-if="combo.descripcion" class="text-sm text-slate-500">{{ combo.descripcion }}</p>
    </div>
    <div class="flex items-center gap-3">
      <div class="text-right">
        <span v-if="hayDescuento" class="mr-1 text-xs text-slate-400 line-through">${{ precioSugerido }}</span>
        <span class="whitespace-nowrap font-semibold">${{ combo.precio }}</span>
      </div>
      <button
        type="button"
        @click="agregar"
        class="rounded-md bg-slate-900 px-3 py-1.5 text-sm font-medium text-white hover:bg-slate-700"
      >
        Agregar
      </button>
    </div>
  </li>
</template>
