<script setup>
import { ref, computed, watch } from 'vue'
import { obtenerHistorial } from '../../lib/admin'
import { pesos } from '../../lib/formato'

const props = defineProps({ local: Object })

const PERIODOS = [
  [7, '7 días'],
  [30, '30 días'],
  [90, '90 días'],
  [0, 'Desde el inicio'],
]
const ESTADOS = [
  ['', 'Todos'],
  ['pendiente', 'Pendiente'],
  ['en_preparacion', 'En preparación'],
  ['listo', 'Listo'],
  ['avisado', 'Avisado / retirar'],
  ['entregado', 'Entregado'],
  ['rechazado', 'Rechazado'],
  ['cancelado', 'Cancelado'],
]
const LIMIT = 50

const periodo = ref(30)
const estado = ref('')
const cargando = ref(true)
const cargandoMas = ref(false)
const error = ref(null)
const pedidos = ref([])
const total = ref(0)

let cargado = false
watch(
  () => props.local,
  (l) => {
    if (l && !cargado) {
      cargado = true
      cargar()
    }
  },
  { immediate: true },
)
watch([periodo, estado], () => {
  if (cargado) cargar()
})

async function cargar() {
  cargando.value = true
  error.value = null
  try {
    const r = await obtenerHistorial(props.local.id, {
      dias: periodo.value,
      estado: estado.value || null,
      limit: LIMIT,
      offset: 0,
    })
    pedidos.value = r.pedidos
    total.value = r.total
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

async function cargarMas() {
  cargandoMas.value = true
  try {
    const r = await obtenerHistorial(props.local.id, {
      dias: periodo.value,
      estado: estado.value || null,
      limit: LIMIT,
      offset: pedidos.value.length,
    })
    pedidos.value = pedidos.value.concat(r.pedidos)
    total.value = r.total
  } catch (e) {
    error.value = e.message
  } finally {
    cargandoMas.value = false
  }
}

const hayMas = computed(() => pedidos.value.length < total.value)

const fechaHora = (x) =>
  new Date(x).toLocaleString('es-AR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })

const ESTADO_CLS = {
  pendiente: 'bg-amber-100 text-amber-700',
  en_preparacion: 'bg-blue-100 text-blue-700',
  listo: 'bg-green-100 text-green-700',
  avisado: 'bg-purple-100 text-purple-700',
  entregado: 'bg-slate-100 text-slate-600',
  rechazado: 'bg-red-100 text-red-700',
  cancelado: 'bg-red-100 text-red-700',
}
</script>

<template>
  <section class="max-w-4xl space-y-5">
    <div>
      <h1 class="text-2xl font-bold text-slate-900">Historial de pedidos</h1>
      <p class="text-sm text-slate-500">Todos los pedidos del período, incluidos rechazados y cancelados.</p>
    </div>

    <div class="flex flex-wrap items-center gap-3">
      <div class="flex flex-wrap gap-2">
        <button
          v-for="p in PERIODOS"
          :key="p[0]"
          type="button"
          @click="periodo = p[0]"
          :class="['chip', periodo === p[0] && 'chip-active']"
        >
          {{ p[1] }}
        </button>
      </div>
      <select v-model="estado" class="input w-52">
        <option v-for="e in ESTADOS" :key="e[0]" :value="e[0]">{{ e[1] }}</option>
      </select>
    </div>

    <p v-if="error" class="text-red-600">{{ error }}</p>
    <p v-else-if="cargando" class="text-slate-500">Cargando…</p>

    <template v-else>
      <p class="text-xs text-slate-400">{{ total }} pedido(s)</p>

      <div class="card overflow-x-auto p-0">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-slate-200 bg-slate-50 text-left text-xs text-slate-400">
              <th class="px-4 py-2.5 font-medium">#</th>
              <th class="px-4 py-2.5 font-medium">Fecha</th>
              <th class="px-4 py-2.5 font-medium">Cliente</th>
              <th class="px-4 py-2.5 font-medium">Entrega</th>
              <th class="px-4 py-2.5 font-medium">Pago</th>
              <th class="px-4 py-2.5 text-right font-medium">Ítems</th>
              <th class="px-4 py-2.5 text-right font-medium">Total</th>
              <th class="px-4 py-2.5 font-medium">Estado</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="p in pedidos" :key="p.numero" class="hover:bg-slate-50">
              <td class="px-4 py-2.5 font-bold text-slate-900">#{{ p.numero }}</td>
              <td class="whitespace-nowrap px-4 py-2.5 text-slate-500">{{ fechaHora(p.created_at) }}</td>
              <td class="px-4 py-2.5 text-slate-900">
                {{ p.nombre_cliente }}
                <span class="block text-xs text-slate-400">{{ p.telefono_cliente }}</span>
              </td>
              <td class="px-4 py-2.5 text-slate-500">
                {{ p.tipo_entrega === 'delivery' ? `Delivery${p.direccion_barrio ? ' · ' + p.direccion_barrio : ''}` : 'Retiro' }}
              </td>
              <td class="px-4 py-2.5 text-slate-500">{{ p.metodo_pago === 'efectivo' ? 'Efectivo' : 'Transf.' }}</td>
              <td class="px-4 py-2.5 text-right text-slate-600">{{ p.items }}</td>
              <td class="px-4 py-2.5 text-right font-medium text-slate-900">{{ pesos(p.total) }}</td>
              <td class="px-4 py-2.5">
                <span :class="['rounded-full px-2 py-0.5 text-[11px] font-medium', ESTADO_CLS[p.estado] ?? 'bg-slate-100 text-slate-600']">
                  {{ p.estado.replace('_', ' ') }}
                </span>
              </td>
            </tr>
            <tr v-if="!pedidos.length">
              <td colspan="8" class="px-4 py-6 text-center text-slate-400">No hay pedidos con esos filtros.</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="hayMas" class="text-center">
        <button type="button" :disabled="cargandoMas" @click="cargarMas" class="btn btn-ghost">
          {{ cargandoMas ? 'Cargando…' : `Cargar más (${total - pedidos.length} restantes)` }}
        </button>
      </div>
    </template>
  </section>
</template>
