<script setup>
import { ref, computed, watch } from 'vue'
import { obtenerEstadisticas } from '../../lib/admin'
import { pesos } from '../../lib/formato'

const props = defineProps({ local: Object })

const cargando = ref(true)
const error = ref(null)
const stats = ref(null)

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
    stats.value = await obtenerEstadisticas(props.local.id)
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

const ticketHoy = computed(() => {
  if (!stats.value || !stats.value.pedidos_hoy) return 0
  return Number(stats.value.ventas_hoy) / stats.value.pedidos_hoy
})

const reportes = computed(() => (props.local ? `/panel/${props.local.slug}/admin/reportes` : ''))
const menu = computed(() => (props.local ? `/panel/${props.local.slug}/admin/menu` : ''))

// Tarjetas de "hoy" + una fila de contexto (7 días / mes). Cada una linkea
// al reporte con el detalle (productos activos va al menú).
const hoy = computed(() => [
  { label: 'Pedidos hoy', valor: stats.value?.pedidos_hoy ?? 0, to: reportes.value },
  { label: 'Ventas hoy', valor: pesos(stats.value?.ventas_hoy ?? 0), to: reportes.value },
  { label: 'Ticket promedio', valor: pesos(ticketHoy.value), to: reportes.value },
  { label: 'Productos activos', valor: stats.value?.productos_activos ?? 0, to: menu.value },
])
const periodos = computed(() => [
  { label: 'Pedidos · últimos 7 días', valor: stats.value?.pedidos_7d ?? 0, to: reportes.value },
  { label: 'Ventas · últimos 7 días', valor: pesos(stats.value?.ventas_7d ?? 0), to: reportes.value },
  { label: 'Ventas del mes', valor: pesos(stats.value?.ventas_mes ?? 0), to: reportes.value },
])
</script>

<template>
  <section>
    <h1 class="text-2xl font-bold text-slate-900">Hola{{ local ? `, ${local.nombre}` : '' }} 👋</h1>
    <p class="mt-1 text-sm text-slate-500">Resumen de tu local. Horario de Argentina.</p>

    <p v-if="error" class="mt-4 text-sm text-red-600">{{ error }}</p>

    <!-- Hoy -->
    <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <RouterLink
        v-for="s in hoy"
        :key="s.label"
        :to="s.to"
        class="card group p-4 transition hover:border-brand-300 hover:shadow-md"
      >
        <p class="label">{{ s.label }}</p>
        <p class="mt-2 text-2xl font-extrabold text-slate-900">
          <span v-if="cargando" class="text-slate-300">—</span>
          <span v-else>{{ s.valor }}</span>
        </p>
        <span class="mt-1 inline-block text-[11px] text-slate-400 group-hover:text-brand-600">Ver detalle →</span>
      </RouterLink>
    </div>

    <!-- Contexto -->
    <div class="mt-4 grid gap-4 sm:grid-cols-3">
      <RouterLink
        v-for="s in periodos"
        :key="s.label"
        :to="s.to"
        class="rounded-xl border border-slate-200 bg-white p-4 transition hover:border-brand-300 hover:shadow-sm"
      >
        <p class="text-xs font-medium text-slate-500">{{ s.label }}</p>
        <p class="mt-1 text-lg font-bold text-slate-900">
          <span v-if="cargando" class="text-slate-300">—</span>
          <span v-else>{{ s.valor }}</span>
        </p>
      </RouterLink>
    </div>

    <h2 class="mt-8 text-sm font-semibold text-slate-500">Accesos rápidos</h2>
    <div v-if="local" class="mt-3 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <RouterLink
        :to="`/panel/${local.slug}/admin/menu`"
        class="card p-5 transition hover:border-brand-300 hover:shadow-md"
      >
        <p class="text-base font-semibold text-slate-900">Menú</p>
        <p class="mt-1 text-sm text-slate-500">Categorías, productos y combos de tu carta.</p>
        <span class="mt-3 inline-block text-sm font-medium t-brand">Abrir →</span>
      </RouterLink>

      <RouterLink
        :to="`/panel/${local.slug}/admin/promos`"
        class="card p-5 transition hover:border-brand-300 hover:shadow-md"
      >
        <p class="text-base font-semibold text-slate-900">Promos</p>
        <p class="mt-1 text-sm text-slate-500">3x2, happy hour y precios especiales por franja.</p>
        <span class="mt-3 inline-block text-sm font-medium t-brand">Abrir →</span>
      </RouterLink>

      <RouterLink
        :to="`/panel/${local.slug}`"
        class="card p-5 transition hover:border-brand-300 hover:shadow-md"
      >
        <p class="text-base font-semibold text-slate-900">Pedidos (KDS)</p>
        <p class="mt-1 text-sm text-slate-500">La pantalla en vivo para la barra y la cocina.</p>
        <span class="mt-3 inline-block text-sm font-medium t-brand">Abrir →</span>
      </RouterLink>

      <RouterLink
        :to="`/panel/${local.slug}/admin/config`"
        class="card p-5 transition hover:border-brand-300 hover:shadow-md"
      >
        <p class="text-base font-semibold text-slate-900">Configuración del local</p>
        <p class="mt-1 text-sm text-slate-500">Horarios, imagen de la carta, pago y delivery.</p>
        <span class="mt-3 inline-block text-sm font-medium t-brand">Abrir →</span>
      </RouterLink>
    </div>
  </section>
</template>
