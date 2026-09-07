<script setup>
import { ref, onMounted, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { obtenerLocalPorSlug, obtenerMenu } from '../lib/locales'
import { useCartStore } from '../stores/cart'
import ProductoCard from '../components/ProductoCard.vue'
import ComboCard from '../components/ComboCard.vue'
import CarritoResumen from '../components/CarritoResumen.vue'

const route = useRoute()
const cart = useCartStore()

const cargando = ref(true)
const error = ref(null)
const local = ref(null)
const categorias = ref([])
const productos = ref([])
const combos = ref([])

// Agrupa productos por categoría, en el orden de las categorías.
const menuAgrupado = computed(() =>
  categorias.value.map((cat) => ({
    ...cat,
    productos: productos.value.filter((p) => p.categoria_id === cat.id),
  })),
)

async function cargar(slug) {
  cargando.value = true
  error.value = null
  try {
    local.value = await obtenerLocalPorSlug(slug)
    if (!local.value) {
      error.value = 'No encontramos este local.'
      return
    }
    cart.inicializarParaLocal(slug)
    const menu = await obtenerMenu(local.value.id)
    categorias.value = menu.categorias
    productos.value = menu.productos
    combos.value = menu.combos
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

onMounted(() => cargar(route.params.slug))
watch(() => route.params.slug, (slug) => cargar(slug))
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>

  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="pb-56">
    <h1 class="text-xl font-semibold">{{ local.nombre }}</h1>
    <p class="mt-1 text-sm text-slate-500">No hagas fila: escaneá, elegí y esperá tu pedido.</p>

    <div v-if="combos.length" class="mt-6">
      <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">Combos</h2>
      <ul class="mt-2 divide-y divide-slate-200 rounded-lg border border-slate-200 bg-white">
        <ComboCard v-for="c in combos" :key="c.id" :combo="c" />
      </ul>
    </div>

    <div v-for="cat in menuAgrupado" :key="cat.id" class="mt-6">
      <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">
        {{ cat.nombre }}
      </h2>
      <ul class="mt-2 divide-y divide-slate-200 rounded-lg border border-slate-200 bg-white">
        <ProductoCard v-for="p in cat.productos" :key="p.id" :producto="p" />
      </ul>
    </div>

    <CarritoResumen />
  </section>
</template>
