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

const valorDe = (d) => (metrica.value === 'ventas' ? Number(d.ventas) : d.pedidos)
const maxSerie = computed(() => Math.max(1, ...serie.value.map(valorDe)))
const altura = (d) => Math.round((valorDe(d) / maxSerie.value) * 100)
const etiquetaValor = (v) => (metrica.value === 'ventas' ? pesos(v) : `${Math.round(v)}`)
const valorDia = (d) => (metrica.value === 'ventas' ? pesos(d.ventas) : `${d.pedidos} pedido(s)`)

// 3 líneas de referencia (0 / mitad / máximo) para que el gráfico tenga escala.
const gridlines = computed(() => [0, 50, 100].map((p) => ({ pct: p, label: etiquetaValor((maxSerie.value * p) / 100) })))

const diaPico = computed(() => {
  if (!serie.value.length) return null
  return serie.value.reduce((a, b) => (valorDe(b) > valorDe(a) ? b : a))
})

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

      <p class="mt-1 text-xs text-slate-400">
        {{ metrica === 'ventas' ? 'Cuánto facturaste cada día ($).' : 'Cuántos pedidos entraron cada día.' }}
        <span v-if="diaPico"> · Pico: {{ valorDia(diaPico) }} el {{ dm(diaPico.fecha) }}.</span>
      </p>

      <!-- Gráfico con escala -->
      <div class="relative mt-6 h-44">
        <div
          v-for="g in gridlines"
          :key="g.pct"
          class="absolute inset-x-0 border-t border-dashed border-slate-200"
          :style="{ bottom: g.pct + '%' }"
        >
          <span class="absolute -top-2 left-0 bg-white pr-1 text-[10px] text-slate-400">{{ g.label }}</span>
        </div>

        <div class="absolute inset-0 flex items-end gap-1 pl-12">
          <div v-for="d in serie" :key="d.fecha" class="group relative flex-1">
            <div
              class="min-h-[3px] w-full rounded-t bg-brand-500/80 transition group-hover:bg-brand-500"
              :style="{ height: altura(d) + '%' }"
            />
            <div
              class="pointer-events-none absolute -top-7 left-1/2 z-10 hidden -translate-x-1/2 whitespace-nowrap rounded bg-slate-900 px-1.5 py-1 text-[10px] font-medium text-white group-hover:block"
            >
              {{ dm(d.fecha) }} · {{ valorDia(d) }}
            </div>
          </div>
        </div>
      </div>
      <div class="mt-1.5 flex justify-between pl-12 text-[11px] text-slate-400">
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
