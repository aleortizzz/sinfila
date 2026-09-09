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

// Tarjetas de "hoy" + una fila de contexto (7 días / mes).
const hoy = computed(() => [
  { label: 'Pedidos hoy', valor: stats.value?.pedidos_hoy ?? 0 },
  { label: 'Ventas hoy', valor: pesos(stats.value?.ventas_hoy ?? 0) },
  { label: 'Ticket promedio', valor: pesos(ticketHoy.value) },
  { label: 'Productos activos', valor: stats.value?.productos_activos ?? 0 },
])
const periodos = computed(() => [
  { label: 'Pedidos · últimos 7 días', valor: stats.value?.pedidos_7d ?? 0 },
  { label: 'Ventas · últimos 7 días', valor: pesos(stats.value?.ventas_7d ?? 0) },
  { label: 'Ventas del mes', valor: pesos(stats.value?.ventas_mes ?? 0) },
])
</script>

<template>
  <section>
    <h1 class="text-2xl font-bold text-slate-900">Hola{{ local ? `, ${local.nombre}` : '' }} 👋</h1>
    <p class="mt-1 text-sm text-slate-500">Resumen de tu local. Horario de Argentina.</p>

    <p v-if="error" class="mt-4 text-sm text-red-600">{{ error }}</p>

    <!-- Hoy -->
    <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div v-for="s in hoy" :key="s.label" class="card p-4">
        <p class="label">{{ s.label }}</p>
        <p class="mt-2 text-2xl font-extrabold text-slate-900">
          <span v-if="cargando" class="text-slate-300">—</span>
          <span v-else>{{ s.valor }}</span>
        </p>
      </div>
    </div>

    <!-- Contexto -->
    <div class="mt-4 grid gap-4 sm:grid-cols-3">
      <div v-for="s in periodos" :key="s.label" class="rounded-xl border border-slate-200 bg-white p-4">
        <p class="text-xs font-medium text-slate-500">{{ s.label }}</p>
        <p class="mt-1 text-lg font-bold text-slate-900">
          <span v-if="cargando" class="text-slate-300">—</span>
          <span v-else>{{ s.valor }}</span>
        </p>
      </div>
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
