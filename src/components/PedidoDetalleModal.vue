<script setup>
import { ref, onMounted } from 'vue'
import { obtenerDetallePedido } from '../lib/admin'
import { pesos } from '../lib/formato'

const props = defineProps({ pedidoId: { type: String, required: true } })
const emit = defineEmits(['cerrar'])

const cargando = ref(true)
const error = ref(null)
const p = ref(null)

onMounted(async () => {
  try {
    p.value = await obtenerDetallePedido(props.pedidoId)
    if (!p.value) error.value = 'No se encontró el pedido.'
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
})

const fechaHora = (x) =>
  new Date(x).toLocaleString('es-AR', {
    weekday: 'short', day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit',
  })
const hora = (x) => new Date(x).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })

const ESTADO_TXT = {
  pendiente: 'Pendiente', en_preparacion: 'En preparación', listo: 'Listo',
  avisado: 'Avisado / a retirar', entregado: 'Entregado', rechazado: 'Rechazado', cancelado: 'Cancelado',
}
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-0 sm:items-center sm:p-6" @click.self="emit('cerrar')">
    <div class="flex max-h-[88dvh] w-full max-w-lg flex-col rounded-t-2xl bg-white shadow-2xl sm:rounded-2xl">
      <div class="flex items-center justify-between border-b border-slate-200 px-5 py-3">
        <h2 class="text-base font-bold text-slate-900">
          {{ cargando ? 'Cargando…' : p ? `Pedido #${p.numero}` : 'Pedido' }}
        </h2>
        <button type="button" @click="emit('cerrar')" class="text-sm font-medium text-slate-500 hover:text-slate-900">
          Cerrar
        </button>
      </div>

      <div class="flex-1 overflow-y-auto px-5 py-4">
        <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

        <template v-else-if="p">
          <p class="text-sm text-slate-500">{{ fechaHora(p.created_at) }}</p>
          <span class="mt-1 inline-block rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-semibold text-slate-700">
            {{ ESTADO_TXT[p.estado] ?? p.estado }}
          </span>

          <!-- Cliente -->
          <div class="mt-4">
            <p class="label">Cliente</p>
            <p class="mt-1 font-medium text-slate-900">{{ p.nombre_cliente }}</p>
            <p class="text-sm text-slate-500">{{ p.telefono_cliente }}</p>
          </div>

          <!-- Entrega -->
          <div class="mt-4">
            <p class="label">Entrega</p>
            <template v-if="p.tipo_entrega === 'delivery' && p.direccion">
              <p class="mt-1 text-sm text-slate-900">
                🛵 Delivery — {{ p.direccion.calle }} {{ p.direccion.numero }}<span v-if="p.direccion.piso_depto">, {{ p.direccion.piso_depto }}</span>
              </p>
              <p class="text-sm text-slate-500">{{ p.direccion.barrio }}</p>
              <p v-if="p.direccion.referencia" class="text-sm text-slate-500">Ref: {{ p.direccion.referencia }}</p>
              <a v-if="p.direccion.maps_url" :href="p.direccion.maps_url" target="_blank" rel="noopener" class="text-sm font-medium t-brand underline">
                Ver en el mapa ↗
              </a>
            </template>
            <p v-else class="mt-1 text-sm text-slate-900">🏠 Retiro en el local</p>
          </div>

          <!-- Pago -->
          <div class="mt-4">
            <p class="label">Pago</p>
            <p class="mt-1 text-sm text-slate-900">
              {{ p.metodo_pago === 'efectivo' ? '💵 Efectivo' : '🏦 Transferencia' }}
              <span v-if="p.metodo_pago === 'transferencia'" class="text-slate-500">
                — {{ p.transferencia_avisada ? 'el cliente avisó que transfirió' : 'no avisó' }}
              </span>
            </p>
          </div>

          <!-- Items -->
          <div class="mt-4">
            <p class="label">Pedido</p>
            <ul class="mt-1 divide-y divide-slate-100 text-sm">
              <li v-for="(it, i) in p.items" :key="i" class="flex justify-between gap-3 py-2">
                <div class="min-w-0">
                  <p class="text-slate-900"><span class="font-semibold">{{ it.cantidad }}×</span> {{ it.nombre }}</p>
                  <p v-if="it.opciones && it.opciones.length" class="text-xs text-slate-500">
                    {{ it.opciones.map((o) => o.opcion).join(', ') }}
                  </p>
                  <p v-if="Number(it.descuento_aplicado) > 0" class="text-xs text-green-600">
                    promo −{{ pesos(Number(it.descuento_aplicado) * it.cantidad) }}
                  </p>
                </div>
                <span class="shrink-0 font-medium text-slate-900">
                  {{ pesos((Number(it.precio_unitario) - Number(it.descuento_aplicado || 0)) * it.cantidad) }}
                </span>
              </li>
            </ul>
          </div>

          <!-- Totales -->
          <div class="mt-3 space-y-1 border-t border-slate-200 pt-3 text-sm">
            <div class="flex justify-between text-slate-500"><span>Subtotal</span><span>{{ pesos(p.subtotal) }}</span></div>
            <div v-if="Number(p.descuento_promos) > 0" class="flex justify-between font-medium text-green-600">
              <span>Descuento (promo)</span><span>−{{ pesos(p.descuento_promos) }}</span>
            </div>
            <div v-if="Number(p.costo_delivery) > 0" class="flex justify-between text-slate-500">
              <span>Envío</span><span>{{ pesos(p.costo_delivery) }}</span>
            </div>
            <div class="flex justify-between pt-1 text-base font-bold text-slate-900">
              <span>Total</span><span>{{ pesos(p.total) }}</span>
            </div>
          </div>

          <!-- Timeline -->
          <div v-if="p.historial && p.historial.length" class="mt-4">
            <p class="label">Estados</p>
            <ul class="mt-1 space-y-1 text-sm text-slate-600">
              <li v-for="(h, i) in p.historial" :key="i" class="flex justify-between">
                <span>{{ ESTADO_TXT[h.estado] ?? h.estado }}</span>
                <span class="text-slate-400">{{ hora(h.at) }}</span>
              </li>
            </ul>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>
