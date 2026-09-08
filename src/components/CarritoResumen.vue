<script setup>
import { ref, computed, watch, onUnmounted } from 'vue'
import { RouterLink } from 'vue-router'
import { useCartStore } from '../stores/cart'
import { pesos } from '../lib/formato'

const props = defineProps({
  cerrado: { type: Boolean, default: false },
  // Resultado de previsualizar_pedido: { subtotal, descuento_promos, total } o null.
  // Todos los montos salen de acá (misma respuesta), nunca cruzados con el
  // subtotal del cliente — así una respuesta vieja no descuadra la barra.
  preview: { type: Object, default: null },
})

const cart = useCartStore()

// Colapsado = pill mientras navegás. Abierto = sheet modal con backdrop:
// estás revisando el pedido, no navegando (se bloquea el scroll de fondo).
const abierto = ref(false)

// Bloquea el scroll de fondo solo mientras el sheet está visible de verdad
// (abierto y con ítems). Si el carrito se vacía desde el sheet, se libera.
watch(
  [abierto, () => cart.items.length],
  ([open, n]) => {
    document.body.style.overflow = open && n > 0 ? 'hidden' : ''
  },
)
onUnmounted(() => {
  document.body.style.overflow = ''
})

const hayPromo = computed(() => !!props.preview && Number(props.preview.descuento_promos) > 0)
const descuento = computed(() => (props.preview ? Number(props.preview.descuento_promos) : 0))
const montoTachado = computed(() => (hayPromo.value ? Number(props.preview.subtotal) : null))
const totalMostrado = computed(() => (hayPromo.value ? Number(props.preview.total) : cart.subtotal))
</script>

<template>
  <div v-if="cart.items.length">
    <!-- Colapsado: pill -->
    <div v-if="!abierto" class="fixed inset-x-0 bottom-0 z-30 px-4 pb-4">
      <div class="mx-auto max-w-lg">
        <button
          type="button"
          @click="abierto = true"
          class="btn btn-brand w-full justify-between px-5 py-3.5 text-base shadow-xl"
        >
          <span class="flex items-center gap-2">
            <span class="flex h-6 min-w-6 items-center justify-center rounded-full bg-white/25 px-1.5 text-xs font-bold">
              {{ cart.cantidadTotal }}
            </span>
            Ver pedido
          </span>
          <span class="flex items-baseline gap-1.5">
            <span v-if="hayPromo" class="text-sm font-normal text-white/60 line-through">{{ pesos(montoTachado) }}</span>
            <span>{{ pesos(totalMostrado) }}</span>
          </span>
        </button>
      </div>
    </div>

    <!-- Abierto: sheet modal -->
    <template v-else>
      <div class="fixed inset-0 z-40 bg-black/30" @click="abierto = false" />

      <div
        class="fixed inset-x-0 bottom-0 z-50 mx-auto flex max-h-[80dvh] max-w-lg flex-col rounded-t-2xl bg-white shadow-2xl"
      >
        <div class="flex items-center justify-between px-4 pb-1 pt-4">
          <h2 class="label">Tu pedido</h2>
          <button
            type="button"
            @click="abierto = false"
            class="text-sm font-medium text-slate-500 hover:text-slate-900"
          >
            Seguir pidiendo
          </button>
        </div>

        <ul class="flex-1 divide-y divide-slate-100 overflow-y-auto px-4 pb-2">
          <li
            v-for="item in cart.items"
            :key="item.id"
            class="flex items-center justify-between gap-2 py-2.5 text-sm"
          >
            <div class="min-w-0">
              <p class="truncate font-medium text-slate-900">{{ item.nombre }}</p>
              <p v-if="item.opciones.length" class="truncate text-xs text-slate-500">
                {{ item.opciones.map((o) => o.opcionNombre).join(', ') }}
              </p>
            </div>
            <div class="flex shrink-0 items-center gap-3">
              <div class="flex items-center gap-1.5">
                <button
                  type="button"
                  @click="cart.cambiarCantidad(item.id, item.cantidad - 1)"
                  class="flex h-7 w-7 items-center justify-center rounded-full border border-slate-300 text-slate-600 hover:bg-slate-100"
                >
                  −
                </button>
                <span class="w-4 text-center font-medium">{{ item.cantidad }}</span>
                <button
                  type="button"
                  @click="cart.cambiarCantidad(item.id, item.cantidad + 1)"
                  class="flex h-7 w-7 items-center justify-center rounded-full border border-slate-300 text-slate-600 hover:bg-slate-100"
                >
                  +
                </button>
              </div>
              <span class="w-16 text-right font-semibold text-slate-900">
                {{ pesos(cart.precioUnitario(item) * item.cantidad) }}
              </span>
              <button
                type="button"
                @click="cart.quitar(item.id)"
                aria-label="Quitar"
                class="flex h-7 w-7 items-center justify-center rounded-full text-slate-400 hover:bg-slate-100 hover:text-brand-600"
              >
                ✕
              </button>
            </div>
          </li>
        </ul>

        <div class="border-t border-slate-200 px-4 py-3">
          <div v-if="hayPromo" class="mb-2 space-y-1 text-sm">
            <div class="flex justify-between text-slate-500">
              <span>Subtotal</span><span>{{ pesos(montoTachado) }}</span>
            </div>
            <div class="flex justify-between font-medium text-green-600">
              <span>Descuento (promo)</span><span>-{{ pesos(descuento) }}</span>
            </div>
          </div>

          <div
            v-if="cerrado"
            class="btn btn-brand w-full cursor-not-allowed justify-center py-3 text-base opacity-60"
          >
            Local cerrado — no se puede pedir
          </div>
          <RouterLink
            v-else
            :to="`/${cart.localSlug}/checkout`"
            class="btn btn-brand w-full justify-between py-3 text-base"
          >
            <span>Ir al pago</span>
            <span class="flex items-baseline gap-1.5">
              <span v-if="hayPromo" class="text-sm font-normal text-white/60 line-through">{{ pesos(montoTachado) }}</span>
              <span>{{ pesos(totalMostrado) }}</span>
            </span>
          </RouterLink>
        </div>
      </div>
    </template>
  </div>
</template>
