<script setup>
import { ref, onMounted, onBeforeUnmount, computed, watch, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import {
  obtenerLocalPorSlug,
  obtenerMenu,
  estaAbierto,
  obtenerHorarios,
  obtenerPromosVigentes,
} from '../lib/locales'
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
const abierto = ref(true) // hasta saberlo, no bloqueamos nada
const horarios = ref([])
const promosVigentes = ref([]) // [{ producto_id, tipo, precio_especial, descuento_pct, n, m }]

// producto_id -> mejor promo para mostrar en la tarjeta. Misma idea que el
// motor del server: la de mayor descuento para ESE producto. Es solo para
// mostrar — el precio real lo recalcula crear_pedido / previsualizar_pedido.
const promoPorProducto = computed(() => {
  const map = new Map()
  for (const r of promosVigentes.value) {
    const prod = productos.value.find((p) => p.id === r.producto_id)
    if (!prod) continue
    const precio = Number(prod.precio)
    let precioPromo = precio
    let etiqueta = null
    if (r.tipo === 'precio_especial') {
      precioPromo = Math.min(precio, Number(r.precio_especial))
    } else if (r.tipo === 'porcentaje') {
      precioPromo = Math.round(precio * (1 - Number(r.descuento_pct) / 100))
      etiqueta = `-${Number(r.descuento_pct)}%`
    } else if (r.tipo === 'nxm') {
      etiqueta = `${r.n}x${r.m}`
    }
    const ahorro = precio - precioPromo
    const actual = map.get(r.producto_id)
    // Nos quedamos con la de más ahorro; si no hay ahorro unitario (nxm),
    // igual guardamos su etiqueta si no había nada mejor.
    if (!actual || ahorro > actual.ahorro) {
      map.set(r.producto_id, { tipo: r.tipo, precioPromo, etiqueta, ahorro })
    }
  }
  return map
})

const promoDe = (id) => promoPorProducto.value.get(id) ?? null

const DIAS = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
const ORDEN_SEMANA = [1, 2, 3, 4, 5, 6, 0]

// Día de hoy en hora de Argentina (0 = domingo, como extract(dow) en la base).
const hoyDow = computed(() => {
  const corto = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Argentina/Buenos_Aires',
    weekday: 'short',
  }).format(new Date())
  return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(corto)
})

const horariosOrdenados = computed(() =>
  ORDEN_SEMANA.map((d) => horarios.value.find((h) => h.dia === d)).filter(Boolean),
)

const hhmm = (t) => (t ? String(t).slice(0, 5) : '')
function textoHorario(h) {
  if (!h || !h.abierto) return 'Cerrado'
  if (!h.apertura || !h.cierre) return 'Abierto todo el día'
  return `${hhmm(h.apertura)} – ${hhmm(h.cierre)}`
}

// Categorías con al menos un producto, en el orden de las categorías.
const menuAgrupado = computed(() =>
  categorias.value
    .map((cat) => ({
      ...cat,
      productos: productos.value.filter((p) => p.categoria_id === cat.id),
    }))
    .filter((cat) => cat.productos.length),
)

// Secciones para la nav pegajosa: "Combos" (si hay) + cada categoría con
// productos. El id es el ancla a la que scrollea el chip.
const secciones = computed(() => {
  const s = []
  if (combos.value.length) s.push({ id: 'combos', nombre: 'Combos' })
  for (const c of menuAgrupado.value) s.push({ id: `cat-${c.id}`, nombre: c.nombre })
  return s
})

// Chip resaltado según qué sección se está mirando.
const seccionActiva = ref(null)
let observer = null

function observarSecciones() {
  observer?.disconnect()
  observer = new IntersectionObserver(
    (entradas) => {
      for (const e of entradas) {
        if (e.isIntersecting) seccionActiva.value = e.target.id
      }
    },
    // La franja "activa" es la zona alta del viewport, justo debajo de la nav.
    { rootMargin: '-120px 0px -70% 0px' },
  )
  for (const s of secciones.value) {
    const el = document.getElementById(s.id)
    if (el) observer.observe(el)
  }
}

function irA(id) {
  document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

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
    const [menu, ab, hs, prs] = await Promise.all([
      obtenerMenu(local.value.id),
      estaAbierto(local.value.id).catch(() => true),
      obtenerHorarios(local.value.id).catch(() => []),
      obtenerPromosVigentes(local.value.id).catch(() => []),
    ])
    categorias.value = menu.categorias
    productos.value = menu.productos
    combos.value = menu.combos
    abierto.value = ab
    horarios.value = hs
    promosVigentes.value = prs
    await nextTick()
    observarSecciones()
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

onMounted(() => cargar(route.params.slug))
watch(() => route.params.slug, (slug) => cargar(slug))
onBeforeUnmount(() => observer?.disconnect())
</script>

<template>
  <div
    class="min-h-screen overflow-x-clip bg-sand-50"
    :style="local && local.color_primario ? { '--brand': local.color_primario } : null"
  >
    <!-- Cargando -->
    <div v-if="cargando" class="flex min-h-screen items-center justify-center">
      <div class="h-9 w-9 animate-spin rounded-full border-[3px] border-slate-300 border-t-transparent" />
    </div>

    <!-- Error -->
    <div v-else-if="error" class="mx-auto max-w-md px-5 py-24 text-center">
      <p class="text-lg font-semibold text-slate-900">{{ error }}</p>
      <p class="mt-1 text-sm text-slate-500">Revisá el link e intentá de nuevo.</p>
    </div>

    <template v-else>
      <!-- Hero / banner -->
      <header class="relative">
        <div class="h-40 w-full overflow-hidden bg-slate-200 sm:h-52">
          <img
            v-if="local.banner_url"
            :src="local.banner_url"
            alt=""
            class="h-full w-full object-cover"
          />
          <div
            v-else
            class="h-full w-full"
            style="background: linear-gradient(135deg, var(--brand), #1a1613)"
          />
          <div class="absolute inset-x-0 top-0 h-40 bg-linear-to-t from-transparent to-black/25 sm:h-52" />
        </div>

        <div class="mx-auto -mt-10 max-w-5xl px-5">
          <div class="flex items-end gap-4">
            <div class="flex h-20 w-20 shrink-0 items-center justify-center overflow-hidden rounded-2xl border-4 border-sand-50 bg-white shadow-md">
              <img v-if="local.logo_url" :src="local.logo_url" alt="" class="h-full w-full object-cover" />
              <span v-else class="text-2xl font-extrabold t-brand">{{ local.nombre.charAt(0) }}</span>
            </div>
            <div class="min-w-0 pb-1">
              <h1 class="truncate text-2xl font-extrabold text-slate-900 sm:text-3xl">{{ local.nombre }}</h1>
              <div class="flex items-center gap-2">
                <span
                  :class="[
                    'inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-semibold',
                    abierto ? 'bg-green-100 text-green-700' : 'bg-slate-200 text-slate-600',
                  ]"
                >
                  <span :class="['h-1.5 w-1.5 rounded-full', abierto ? 'bg-green-500' : 'bg-slate-400']" />
                  {{ abierto ? 'Abierto ahora' : 'Cerrado ahora' }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <!-- Aviso de local cerrado -->
      <div v-if="!abierto" class="mx-auto mt-4 max-w-5xl px-5">
        <div class="rounded-2xl border border-amber-200 bg-amber-50 p-4">
          <p class="text-sm font-semibold text-amber-900">El local está cerrado en este momento</p>
          <p class="mt-0.5 text-sm text-amber-800">
            Podés mirar la carta, pero no se pueden hacer pedidos hasta que abra.
          </p>
          <details v-if="horarios.length" class="mt-2 text-sm text-amber-900">
            <summary class="cursor-pointer font-medium">Ver horarios</summary>
            <ul class="mt-2 space-y-0.5">
              <li
                v-for="h in horariosOrdenados"
                :key="h.dia"
                :class="['flex justify-between', h.dia === hoyDow && 'font-semibold']"
              >
                <span>{{ DIAS[h.dia] }}{{ h.dia === hoyDow ? ' (hoy)' : '' }}</span>
                <span>{{ textoHorario(h) }}</span>
              </li>
            </ul>
          </details>
        </div>
      </div>

      <!-- Nav de categorías (pegajosa) -->
      <nav
        v-if="secciones.length > 1"
        class="sticky top-0 z-20 mt-5 border-b border-sand-200 bg-sand-50/90 backdrop-blur"
      >
        <div class="mx-auto flex max-w-5xl gap-2 overflow-x-auto px-5 py-3 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          <button
            v-for="s in secciones"
            :key="s.id"
            type="button"
            @click="irA(s.id)"
            :class="['chip', seccionActiva === s.id && 'chip-active']"
          >
            {{ s.nombre }}
          </button>
        </div>
      </nav>

      <main class="mx-auto max-w-5xl px-5 pb-40 pt-6">
        <!-- Combos -->
        <section v-if="combos.length" id="combos" class="scroll-mt-24">
          <h2 class="text-lg font-bold text-slate-900">Combos</h2>
          <p class="text-sm text-slate-500">Más rico y más barato que suelto.</p>
          <div class="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <ComboCard v-for="c in combos" :key="c.id" :combo="c" :cerrado="!abierto" />
          </div>
        </section>

        <!-- Categorías -->
        <section
          v-for="cat in menuAgrupado"
          :key="cat.id"
          :id="`cat-${cat.id}`"
          class="mt-10 scroll-mt-24"
        >
          <h2 class="text-lg font-bold text-slate-900">{{ cat.nombre }}</h2>
          <div class="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <ProductoCard
              v-for="p in cat.productos"
              :key="p.id"
              :producto="p"
              :promo="promoDe(p.id)"
              :cerrado="!abierto"
            />
          </div>
        </section>

        <p v-if="!combos.length && !menuAgrupado.length" class="py-16 text-center text-slate-500">
          Este local todavía no cargó su menú.
        </p>
      </main>

      <CarritoResumen :cerrado="!abierto" />
    </template>
  </div>
</template>
