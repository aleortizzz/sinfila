<script setup>
import { ref, computed, watch } from 'vue'
import { obtenerReporte } from '../../lib/admin'
import { pesos } from '../../lib/formato'

const props = defineProps({ local: Object })

const cargando = ref(true)
const error = ref(null)
const data = ref(null)
const metrica = ref('ventas') // 'ventas' | 'pedidos'

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

async function cargar() {
  cargando.value = true
  try {
    data.value = await obtenerReporte(props.local.id)
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

const serie = computed(() => data.value?.serie ?? [])
const top = computed(() => data.value?.top ?? [])
const recientes = computed(() => data.value?.recientes ?? [])

const totalPedidos = computed(() => serie.value.reduce((s, d) => s + d.pedidos, 0))
const totalVentas = computed(() => serie.value.reduce((s, d) => s + Number(d.ventas), 0))

const maxSerie = computed(() => {
  const vals = serie.value.map((d) => (metrica.value === 'ventas' ? Number(d.ventas) : d.pedidos))
  return Math.max(1, ...vals)
})
function altura(d) {
  const v = metrica.value === 'ventas' ? Number(d.ventas) : d.pedidos
  return Math.round((v / maxSerie.value) * 100)
}
function valorDia(d) {
  return metrica.value === 'ventas' ? pesos(d.ventas) : `${d.pedidos} pedido(s)`
}

const dm = (f) => new Date(`${f}T00:00:00`).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' })
const fechaHora = (x) =>
  new Date(x).toLocaleString('es-AR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })

const ESTADO = {
  pendiente: 'bg-amber-100 text-amber-700',
  en_preparacion: 'bg-blue-100 text-blue-700',
  listo: 'bg-green-100 text-green-700',
  avisado: 'bg-purple-100 text-purple-700',
  entregado: 'bg-slate-100 text-slate-600',
}
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="max-w-4xl space-y-6">
    <div>
      <h1 class="text-2xl font-bold text-slate-900">Reportes</h1>
      <p class="text-sm text-slate-500">Últimos 30 días · hora de Argentina · sin rechazados ni cancelados.</p>
    </div>

    <!-- Serie diaria -->
    <div class="card p-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p class="label">Por día</p>
          <p class="mt-1 text-sm text-slate-500">
            {{ totalPedidos }} pedidos · {{ pesos(totalVentas) }} en total
          </p>
        </div>
        <div class="flex gap-2">
          <button
            v-for="op in [['ventas', 'Ventas'], ['pedidos', 'Pedidos']]"
            :key="op[0]"
            type="button"
            @click="metrica = op[0]"
            :class="['chip', metrica === op[0] && 'chip-active']"
          >
            {{ op[1] }}
          </button>
        </div>
      </div>

      <div class="mt-4 flex h-40 items-end gap-1">
        <div
          v-for="d in serie"
          :key="d.fecha"
          :title="`${dm(d.fecha)} — ${valorDia(d)}`"
          class="min-h-[3px] flex-1 rounded-t bg-brand-500/80 transition hover:bg-brand-500"
          :style="{ height: altura(d) + '%' }"
        />
      </div>
      <div class="mt-1.5 flex justify-between text-[11px] text-slate-400">
        <span>{{ serie.length ? dm(serie[0].fecha) : '' }}</span>
        <span>{{ serie.length ? dm(serie[Math.floor(serie.length / 2)].fecha) : '' }}</span>
        <span>{{ serie.length ? dm(serie[serie.length - 1].fecha) : 'hoy' }}</span>
      </div>
    </div>

    <!-- Top productos -->
    <div class="card p-5">
      <p class="label">Más vendidos</p>
      <table class="mt-3 w-full text-sm">
        <thead>
          <tr class="border-b border-slate-200 text-left text-xs text-slate-400">
            <th class="pb-2 font-medium">Producto</th>
            <th class="pb-2 text-right font-medium">Unidades</th>
            <th class="pb-2 text-right font-medium">Monto</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="t in top" :key="t.nombre">
            <td class="py-2 text-slate-900">{{ t.nombre }}</td>
            <td class="py-2 text-right font-medium text-slate-900">{{ t.unidades }}</td>
            <td class="py-2 text-right text-slate-600">{{ pesos(t.monto) }}</td>
          </tr>
          <tr v-if="!top.length">
            <td colspan="3" class="py-3 text-slate-400">Todavía no hay ventas.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Últimos pedidos -->
    <div class="card p-5">
      <p class="label">Últimos pedidos</p>
      <div class="mt-3 overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-slate-200 text-left text-xs text-slate-400">
              <th class="pb-2 pr-3 font-medium">#</th>
              <th class="pb-2 pr-3 font-medium">Fecha</th>
              <th class="pb-2 pr-3 font-medium">Cliente</th>
              <th class="pb-2 pr-3 text-right font-medium">Ítems</th>
              <th class="pb-2 pr-3 font-medium">Pago</th>
              <th class="pb-2 pr-3 text-right font-medium">Total</th>
              <th class="pb-2 font-medium">Estado</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="p in recientes" :key="p.numero">
              <td class="py-2 pr-3 font-bold text-slate-900">#{{ p.numero }}</td>
              <td class="whitespace-nowrap py-2 pr-3 text-slate-500">{{ fechaHora(p.created_at) }}</td>
              <td class="py-2 pr-3 text-slate-900">{{ p.nombre_cliente }}</td>
              <td class="py-2 pr-3 text-right text-slate-600">{{ p.items }}</td>
              <td class="py-2 pr-3 text-slate-500">{{ p.metodo_pago === 'efectivo' ? 'Efectivo' : 'Transf.' }}</td>
              <td class="py-2 pr-3 text-right font-medium text-slate-900">{{ pesos(p.total) }}</td>
              <td class="py-2">
                <span :class="['rounded-full px-2 py-0.5 text-[11px] font-medium', ESTADO[p.estado] ?? 'bg-slate-100 text-slate-600']">
                  {{ p.estado.replace('_', ' ') }}
                </span>
              </td>
            </tr>
            <tr v-if="!recientes.length">
              <td colspan="7" class="py-3 text-slate-400">Todavía no hay pedidos.</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </section>
</template>
