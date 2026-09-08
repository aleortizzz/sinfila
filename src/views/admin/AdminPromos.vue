<script setup>
import { ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { obtenerPromosAdmin, actualizarPromo, eliminarPromo } from '../../lib/admin'

const props = defineProps({ local: Object })
const route = useRoute()
const router = useRouter()

const DIAS = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']

const cargando = ref(true)
const error = ref(null)
const promos = ref([])

let cargado = false
watch(
  () => props.local,
  (v) => {
    if (v && !cargado) {
      cargado = true
      cargar()
    }
  },
  { immediate: true },
)

async function cargar() {
  cargando.value = true
  try {
    promos.value = await obtenerPromosAdmin(props.local.id)
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

function nueva() {
  router.push({ name: 'admin-promo-nueva', params: { slug: route.params.slug } })
}
function editar(p) {
  router.push({ name: 'admin-promo-editar', params: { slug: route.params.slug, promoId: p.id } })
}

async function toggleActiva(p) {
  const activa = !p.activa
  await actualizarPromo(p.id, { activa })
  p.activa = activa
}

async function borrar(p) {
  if (!confirm(`¿Borrar la promo "${p.nombre}"?`)) return
  await eliminarPromo(p.id)
  promos.value = promos.value.filter((x) => x.id !== p.id)
}

function resumenTipo(p) {
  if (p.tipo === 'nxm') return `${p.n}x${p.m}`
  if (p.tipo === 'porcentaje') return `${Number(p.descuento_pct)}% off`
  return `Precio fijo $${p.precio_especial}`
}
function resumenDias(p) {
  return [...p.dias_semana].sort().map((d) => DIAS[d]).join(', ')
}
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="max-w-3xl">
    <div class="flex items-start justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Promos</h1>
        <p class="text-sm text-slate-500">3x2, happy hour, % — se aplican solas en el pedido, sin apilarse.</p>
      </div>
      <button type="button" @click="nueva" class="btn btn-dark shrink-0">+ Nueva promo</button>
    </div>

    <div
      v-if="!promos.length"
      class="mt-6 rounded-xl border border-dashed border-slate-300 p-10 text-center text-slate-500"
    >
      Todavía no hay promos.
    </div>

    <ul v-else class="mt-5 space-y-3">
      <li v-for="p in promos" :key="p.id" class="card flex items-center justify-between gap-4 p-4">
        <div class="min-w-0">
          <p :class="['truncate font-semibold', p.activa ? 'text-slate-900' : 'text-slate-400 line-through']">
            {{ p.nombre }}
          </p>
          <p class="mt-0.5 text-xs text-slate-500">
            {{ resumenTipo(p) }} · {{ resumenDias(p) }} ·
            {{ p.hora_desde.slice(0, 5) }}–{{ p.hora_hasta.slice(0, 5) }} ·
            {{ p.promo_productos.length }} producto(s)
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-4">
          <button
            type="button"
            role="switch"
            :aria-checked="p.activa"
            @click="toggleActiva(p)"
            :class="['relative h-5 w-9 rounded-full transition', p.activa ? 'bg-brand-500' : 'bg-slate-300']"
            title="Activa"
          >
            <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', p.activa ? 'left-4' : 'left-0.5']" />
          </button>
          <button type="button" @click="editar(p)" class="text-xs font-medium text-slate-600 hover:text-slate-900">
            Editar
          </button>
          <button type="button" @click="borrar(p)" class="text-xs font-medium text-red-500 hover:text-red-700">
            Eliminar
          </button>
        </div>
      </li>
    </ul>
  </section>
</template>
