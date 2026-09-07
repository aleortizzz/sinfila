<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { obtenerPedidoPublico } from '../lib/pedidos'

const route = useRoute()

const cargando = ref(true)
const error = ref(null)
const pedido = ref(null)

const ESTADOS_TERMINALES = ['entregado', 'cancelado', 'rechazado']
const PASOS = [
  { estado: 'pendiente', label: 'Recibido' },
  { estado: 'en_preparacion', label: 'Preparando' },
  { estado: 'listo', label: 'Listo' },
  { estado: 'avisado', label: 'Retirar' },
  { estado: 'entregado', label: 'Entregado' },
]

let intervalo = null

async function cargar() {
  try {
    pedido.value = await obtenerPedidoPublico(route.params.id)
    if (ESTADOS_TERMINALES.includes(pedido.value.estado)) detener()
  } catch (e) {
    error.value = e.message
    detener()
  } finally {
    cargando.value = false
  }
}

function detener() {
  if (intervalo) {
    clearInterval(intervalo)
    intervalo = null
  }
}

onMounted(async () => {
  await cargar()
  // Pedido activo -> seguimos consultando cada 5s hasta que llegue a un
  // estado final. Sin Realtime a propósito: el cliente no tiene cuenta,
  // así que no hay forma de darle permiso fino sin abrir una brecha —
  // este polling liviano alcanza de sobra para un local.
  if (pedido.value && !ESTADOS_TERMINALES.includes(pedido.value.estado)) {
    intervalo = setInterval(cargar, 5000)
  }
})

onUnmounted(detener)

const pasoActual = computed(() => PASOS.findIndex((p) => p.estado === pedido.value?.estado))

const mensajePrincipal = computed(() => {
  if (!pedido.value) return ''
  const delivery = pedido.value.tipo_entrega === 'delivery'
  return {
    pendiente: 'Recibimos tu pedido, estamos confirmándolo.',
    en_preparacion: 'Lo estamos preparando.',
    listo: delivery ? 'Ya casi sale hacia tu casa.' : 'Ya casi está.',
    avisado: delivery ? '¡Va en camino! 🛵' : '¡Listo! Pasá a buscarlo. 🎉',
    entregado: delivery ? '¡Entregado! Buen provecho 🎉' : '¡Retirado! Buen provecho 🎉',
    cancelado: 'Este pedido fue cancelado.',
    rechazado: 'El local no pudo tomar este pedido.',
  }[pedido.value.estado]
})
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="mx-auto max-w-sm">
    <p class="text-sm text-slate-500">{{ pedido.local_nombre }}</p>
    <h1 class="text-2xl font-bold">Pedido #{{ pedido.numero }}</h1>
    <p class="mt-2 text-lg font-medium">{{ mensajePrincipal }}</p>

    <!-- Progreso (solo si no se canceló/rechazó) -->
    <div v-if="pasoActual !== -1" class="mt-6 flex justify-between">
      <div v-for="(paso, i) in PASOS" :key="paso.estado" class="flex flex-col items-center text-center">
        <div
          :class="[
            'flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold',
            i <= pasoActual ? 'bg-slate-900 text-white' : 'bg-slate-200 text-slate-400',
          ]"
        >
          {{ i < pasoActual ? '✓' : i + 1 }}
        </div>
        <span class="mt-1 w-16 text-[11px] text-slate-500">{{ paso.label }}</span>
      </div>
    </div>

    <!-- Resumen -->
    <div class="mt-6 rounded-lg border border-slate-200 bg-white p-4">
      <ul class="divide-y divide-slate-200 text-sm">
        <li v-for="(item, i) in pedido.items" :key="i" class="flex justify-between py-2">
          <span>{{ item.cantidad }}× {{ item.nombre }}</span>
          <span>${{ item.precio_unitario * item.cantidad }}</span>
        </li>
      </ul>
      <div v-if="pedido.costo_delivery" class="flex justify-between border-t border-slate-200 pt-2 text-sm text-slate-500">
        <span>Envío</span><span>${{ pedido.costo_delivery }}</span>
      </div>
      <div class="mt-1 flex justify-between border-t border-slate-200 pt-2 font-semibold">
        <span>Total</span><span>${{ pedido.total }}</span>
      </div>
    </div>
  </section>
</template>
