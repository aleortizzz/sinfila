<script setup>
import { ref, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { obtenerReporte, obtenerTopProductos } from '../../lib/admin'
import { pesos } from '../../lib/formato'
import { opcionesPeriodo, periodoPorDefecto, rangoPeriodo } from '../../lib/periodos'

const props = defineProps({ local: Object })
const route = useRoute()

const cargando = ref(true)
const error = ref(null)
const data = ref(null)
const metrica = ref('ventas') // 'ventas' | 'pedidos'
const OPCIONES = computed(() => opcionesPeriodo(props.local?.created_at))
const periodo = ref(periodoPorDefecto())

// Día elegido en el gráfico → filtra "Más vendidos" a ese día.
const diaSel = ref(null)
const topDia = ref([])
const cargandoTop = ref(false)

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
watch(periodo, () => {
  if (cargado) cargar()
})

async function cargar() {
  cargando.value = true
  error.value = null
  diaSel.value = null
  try {
    data.value = await obtenerReporte(props.local.id, rangoPeriodo(periodo.value))
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

async function seleccionarDia(d) {
  if (diaSel.value === d.fecha) return verTodo()
  diaSel.value = d.fecha
  cargandoTop.value = true
  try {
    topDia.value = await obtenerTopProductos(props.local.id, d.fecha, d.fecha)
  } catch {
    topDia.value = []
  } finally {
    cargandoTop.value = false
  }
}
function verTodo() {
  diaSel.value = null
}

const serie = computed(() => data.value?.serie ?? [])
const top = computed(() => data.value?.top ?? [])
const topMostrado = computed(() => (diaSel.value ? topDia.value : top.value))
const resumen = computed(() => data.value?.resumen ?? { pedidos: 0, ventas: 0, ticket: 0 })
const previo = computed(() => data.value?.previo ?? { pedidos: 0, ventas: 0, ticket: 0 })

// Comparación con el período anterior (misma cantidad de días).
function delta(actual, anterior) {
  const a = Number(actual)
  const b = Number(anterior)
  if (!b) return null // sin base de comparación
  const pct = Math.round(((a - b) / b) * 100)
  return { pct, sube: pct > 0, baja: pct < 0 }
}
// Rango del período anterior, para mostrarlo junto al delta ("vs 11/7 al 10/8").
const previoLabel = computed(() => {
  const { prevDesde, prevHasta } = rangoPeriodo(periodo.value)
  if (!prevDesde) return ''
  return prevDesde === prevHasta ? dm(prevDesde) : `${dm(prevDesde)} al ${dm(prevHasta)}`
})
const tarjetas = computed(() => [
  { label: 'Pedidos', valor: resumen.value.pedidos, d: delta(resumen.value.pedidos, previo.value.pedidos) },
  { label: 'Ventas', valor: pesos(resumen.value.ventas), d: delta(resumen.value.ventas, previo.value.ventas) },
  { label: 'Ticket promedio', valor: pesos(resumen.value.ticket), d: delta(resumen.value.ticket, previo.value.ticket) },
])

const valorDe = (d) => (metrica.value === 'ventas' ? Number(d.ventas) : d.pedidos)
const maxSerie = computed(() => Math.max(1, ...serie.value.map(valorDe)))
const altura = (d) => Math.round((valorDe(d) / maxSerie.value) * 100)
const etiquetaValor = (v) => (metrica.value === 'ventas' ? pesos(v) : `${Math.round(v)}`)
const valorDia = (d) => (metrica.value === 'ventas' ? pesos(d.ventas) : `${d.pedidos} pedido(s)`)

const gridlines = computed(() =>
  [0, 50, 100].map((p) => ({ pct: p, label: etiquetaValor((maxSerie.value * p) / 100) })),
)
const diaPico = computed(() => {
  if (!serie.value.length) return null
  return serie.value.reduce((a, b) => (valorDe(b) > valorDe(a) ? b : a))
})

const dm = (f) => new Date(`${f}T00:00:00`).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit' })
const rangoReal = computed(() => {
  if (!serie.value.length) return 'sin datos'
  return `del ${dm(serie.value[0].fecha)} al ${dm(serie.value[serie.value.length - 1].fecha)}`
})
</script>

<template>
  <section class="max-w-4xl space-y-6">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Reportes</h1>
        <p class="text-sm text-slate-500">
          {{ cargando ? 'Cargando…' : rangoReal }} · hora de Argentina · sin rechazados ni cancelados.
        </p>
      </div>
      <select v-model="periodo" class="input w-auto">
        <option v-for="o in OPCIONES" :key="o.id" :value="o.id">{{ o.label }}</option>
      </select>
    </div>

    <p v-if="error" class="text-red-600">{{ error }}</p>
    <p v-else-if="cargando" class="text-slate-500">Cargando…</p>

    <template v-else>
      <!-- Resumen del período + comparación con el anterior -->
      <div class="grid gap-4 sm:grid-cols-3">
        <div v-for="t in tarjetas" :key="t.label" class="card p-4">
          <p class="label">{{ t.label }}</p>
          <p class="mt-2 text-2xl font-extrabold text-slate-900">{{ t.valor }}</p>
          <p
            v-if="t.d"
            :class="['mt-1 text-xs font-medium', t.d.sube ? 'text-green-600' : t.d.baja ? 'text-red-600' : 'text-slate-400']"
          >
            {{ t.d.sube ? '▲' : t.d.baja ? '▼' : '—' }} {{ Math.abs(t.d.pct) }}% vs período anterior
            <span v-if="previoLabel" class="font-normal text-slate-400">({{ previoLabel }})</span>
          </p>
          <p v-else class="mt-1 text-xs text-slate-400">sin período anterior para comparar</p>
        </div>
      </div>

      <!-- Actividad: gráfico + qué se vendió, juntos -->
      <div class="card p-5">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p class="label">Actividad del período</p>
            <p class="mt-1 text-sm text-slate-500">
              {{ metrica === 'ventas' ? 'Lo que facturaste' : 'Los pedidos que entraron' }} día por día.
              Tocá una barra para ver qué se vendió ese día.
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

        <div class="relative mt-6 h-44">
          <div
            v-for="g in gridlines"
            :key="g.pct"
            class="absolute inset-x-0 border-t border-dashed border-slate-200"
            :style="{ bottom: g.pct + '%' }"
          >
            <span class="absolute -top-2 left-0 bg-white pr-1 text-[10px] text-slate-400">{{ g.label }}</span>
          </div>

          <div class="absolute inset-0 flex items-end gap-1 pl-20">
            <button
              v-for="d in serie"
              :key="d.fecha"
              type="button"
              @click="seleccionarDia(d)"
              class="group flex h-full flex-1 items-end"
            >
              <div
                :class="[
                  'relative min-h-[3px] w-full rounded-t transition',
                  diaSel === d.fecha ? 'bg-slate-900' : 'bg-brand-500/80 group-hover:bg-brand-500',
                ]"
                :style="{ height: altura(d) + '%' }"
              >
                <div
                  class="pointer-events-none absolute bottom-full left-1/2 z-10 mb-1 hidden -translate-x-1/2 whitespace-nowrap rounded bg-slate-900 px-1.5 py-1 text-[10px] font-medium text-white group-hover:block"
                >
                  {{ dm(d.fecha) }} · {{ valorDia(d) }}
                </div>
              </div>
            </button>
          </div>
        </div>
        <div class="mt-1.5 flex justify-between pl-20 text-[11px] text-slate-400">
          <span>{{ serie.length ? dm(serie[0].fecha) : '' }}</span>
          <span>{{ serie.length ? dm(serie[Math.floor(serie.length / 2)].fecha) : '' }}</span>
          <span>{{ serie.length ? dm(serie[serie.length - 1].fecha) : 'hoy' }}</span>
        </div>

        <!-- Más vendidos: mismo card, debajo del gráfico -->
        <div class="mt-6 border-t border-slate-200 pt-4">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <p class="text-sm font-semibold text-slate-900">
              Más vendidos
              <span v-if="diaSel" class="text-slate-500">· el {{ dm(diaSel) }}</span>
              <span v-else class="font-normal text-slate-400">· todo el período</span>
            </p>
            <button
              v-if="diaSel"
              type="button"
              @click="verTodo"
              class="rounded-full bg-slate-900 px-3 py-1 text-xs font-semibold text-white hover:bg-slate-700"
            >
              ← Ver todo el período
            </button>
          </div>

        <table class="mt-3 w-full text-sm">
          <thead>
            <tr class="border-b border-slate-200 text-left text-xs text-slate-400">
              <th class="pb-2 font-medium">Producto</th>
              <th class="pb-2 text-right font-medium">Unidades</th>
              <th class="pb-2 text-right font-medium">Monto</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="t in topMostrado" :key="t.nombre">
              <td class="py-2 text-slate-900">{{ t.nombre }}</td>
              <td class="py-2 text-right font-medium text-slate-900">{{ t.unidades }}</td>
              <td class="py-2 text-right text-slate-600">{{ pesos(t.monto) }}</td>
            </tr>
            <tr v-if="cargandoTop">
              <td colspan="3" class="py-3 text-slate-400">Cargando…</td>
            </tr>
            <tr v-else-if="!topMostrado.length">
              <td colspan="3" class="py-3 text-slate-400">
                {{ diaSel ? 'Ese día no hubo ventas.' : 'Todavía no hay ventas.' }}
              </td>
            </tr>
          </tbody>
        </table>
        </div>
      </div>

      <RouterLink
        :to="`/panel/${route.params.slug}/admin/historial`"
        class="card flex items-center justify-between p-5 transition hover:border-brand-300 hover:shadow-md"
      >
        <div>
          <p class="text-base font-semibold text-slate-900">Historial de pedidos</p>
          <p class="mt-1 text-sm text-slate-500">Todos los pedidos, con filtros de fecha y estado.</p>
        </div>
        <span class="text-sm font-medium t-brand">Abrir →</span>
      </RouterLink>
    </template>
  </section>
</template>
