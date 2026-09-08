<script setup>
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useCartStore } from '../stores/cart'
import { pesos } from '../lib/formato'

const cart = useCartStore()

// La barra vive siempre abajo. Colapsada = pill con total + cantidad;
// abierta = panel con el detalle y el CTA al pago.
const abierto = ref(false)
</script>

<template>
  <div v-if="cart.items.length" class="fixed inset-x-0 bottom-0 z-30 px-4 pb-4">
    <div class="mx-auto max-w-lg">
      <!-- Panel expandido -->
      <div v-if="abierto" class="card mb-2 p-4 shadow-xl">
        <div class="flex items-center justify-between">
          <h2 class="label">Tu pedido</h2>
          <button
            type="button"
            @click="abierto = false"
            class="text-sm font-medium text-slate-500 hover:text-slate-900"
          >
            Seguir pidiendo
          </button>
        </div>

        <ul class="mt-2 max-h-56 divide-y divide-slate-100 overflow-y-auto">
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
              <button type="button" @click="cart.quitar(item.id)" class="text-slate-300 hover:text-brand-600">
                ✕
              </button>
            </div>
          </li>
        </ul>
      </div>

      <!-- Barra colapsada -->
      <button
        v-if="!abierto"
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
        <span>{{ pesos(cart.subtotal) }}</span>
      </button>

      <RouterLink
        v-else
        :to="`/${cart.localSlug}/checkout`"
        class="btn btn-brand w-full justify-between px-5 py-3.5 text-base shadow-xl"
      >
        <span>Ir al pago</span>
        <span>{{ pesos(cart.subtotal) }}</span>
      </RouterLink>
    </div>
  </div>
</template>
