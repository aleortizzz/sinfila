<script setup>
import { RouterLink } from 'vue-router'
import { useCartStore } from '../stores/cart'

const cart = useCartStore()
</script>

<template>
  <aside
    v-if="cart.items.length"
    class="fixed inset-x-0 bottom-0 border-t border-slate-200 bg-white p-4 shadow-[0_-4px_12px_rgba(0,0,0,0.06)]"
  >
    <div class="mx-auto max-w-3xl">
      <h2 class="text-xs font-semibold uppercase tracking-wide text-slate-500">Tu pedido</h2>

      <ul class="mt-2 max-h-48 divide-y divide-slate-200 overflow-y-auto">
        <li v-for="item in cart.items" :key="item.id" class="flex items-center justify-between gap-2 py-2 text-sm">
          <div class="min-w-0">
            <p class="truncate font-medium">{{ item.nombre }}</p>
            <p v-if="item.opciones.length" class="truncate text-xs text-slate-500">
              {{ item.opciones.map((o) => o.opcionNombre).join(', ') }}
            </p>
          </div>
          <div class="flex shrink-0 items-center gap-3">
            <div class="flex items-center gap-2">
              <button
                type="button"
                @click="cart.cambiarCantidad(item.id, item.cantidad - 1)"
                class="h-6 w-6 rounded border border-slate-300 text-slate-600 hover:bg-slate-100"
              >
                −
              </button>
              <span class="w-4 text-center">{{ item.cantidad }}</span>
              <button
                type="button"
                @click="cart.cambiarCantidad(item.id, item.cantidad + 1)"
                class="h-6 w-6 rounded border border-slate-300 text-slate-600 hover:bg-slate-100"
              >
                +
              </button>
            </div>
            <span class="w-16 text-right font-medium">
              ${{ cart.precioUnitario(item) * item.cantidad }}
            </span>
            <button type="button" @click="cart.quitar(item.id)" class="text-slate-400 hover:text-red-600">
              ✕
            </button>
          </div>
        </li>
      </ul>

      <div class="mt-2 flex items-center justify-between border-t border-slate-200 pt-2">
        <span class="font-semibold">Total</span>
        <span class="font-semibold">${{ cart.subtotal }}</span>
      </div>

      <RouterLink
        :to="`/${cart.localSlug}/checkout`"
        class="mt-3 block w-full rounded-md bg-slate-900 py-2.5 text-center text-sm font-semibold text-white hover:bg-slate-700"
      >
        Ir al checkout
      </RouterLink>
    </div>
  </aside>
</template>
