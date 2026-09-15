<script setup>
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  obtenerCategoriasAdmin,
  crearCategoria,
  actualizarCategoria,
  eliminarCategoria,
  obtenerProductosAdmin,
  actualizarProducto,
  eliminarProducto,
  obtenerCombosAdmin,
  actualizarCombo,
  eliminarCombo,
} from '../../lib/admin'
import { pesos } from '../../lib/formato'

const props = defineProps({ local: Object })
const route = useRoute()
const router = useRouter()

const SECCIONES = [
  ['productos', 'Productos'],
  ['precios', 'Precios en masa'],
  ['pausar', 'Pausar productos'],
  ['stock', 'Stock'],
]
const seccion = ref('productos')

const cargando = ref(true)
const error = ref(null)
const categorias = ref([])
const productos = ref([])
const combos = ref([])

const nuevaCategoria = ref('')
const catEditandoId = ref(null)
const catEditandoNombre = ref('')

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
    const [cats, prods, cmbs] = await Promise.all([
      obtenerCategoriasAdmin(props.local.id),
      obtenerProductosAdmin(props.local.id),
      obtenerCombosAdmin(props.local.id),
    ])
    categorias.value = cats
    productos.value = prods
    combos.value = cmbs
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

const productosDe = (catId) => productos.value.filter((p) => p.categoria_id === catId)

// --- Categorías (rápidas, se editan acá mismo) ---
async function agregarCategoria() {
  if (!nuevaCategoria.value.trim()) return
  const c = await crearCategoria(props.local.id, nuevaCategoria.value.trim(), categorias.value.length)
  categorias.value.push(c)
  nuevaCategoria.value = ''
}
function empezarEdicionCat(c) {
  catEditandoId.value = c.id
  catEditandoNombre.value = c.nombre
}
async function guardarCat(c) {
  if (!catEditandoNombre.value.trim()) return
  await actualizarCategoria(c.id, { nombre: catEditandoNombre.value.trim() })
  c.nombre = catEditandoNombre.value.trim()
  catEditandoId.value = null
}
async function borrarCat(c) {
  if (!confirm(`¿Borrar la categoría "${c.nombre}"?`)) return
  try {
    await eliminarCategoria(c.id)
    categorias.value = categorias.value.filter((x) => x.id !== c.id)
  } catch (e) {
    alert(e.code === '23503' ? 'No se puede: tiene productos. Movelos o borralos primero.' : e.message)
  }
}

// --- Productos / combos: alta y edición en su propia página ---
function nuevoProducto(catId) {
  router.push({ name: 'admin-producto-nuevo', params: { slug: route.params.slug }, query: { categoria: catId } })
}
function editarProducto(p) {
  router.push({ name: 'admin-producto-editar', params: { slug: route.params.slug, productoId: p.id } })
}
function nuevoCombo() {
  router.push({ name: 'admin-combo-nuevo', params: { slug: route.params.slug } })
}
function editarCombo(c) {
  router.push({ name: 'admin-combo-editar', params: { slug: route.params.slug, comboId: c.id } })
}

async function toggleProducto(p) {
  const disponible = !p.disponible
  await actualizarProducto(p.id, { disponible })
  p.disponible = disponible
}
async function borrarProducto(p) {
  if (!confirm(`¿Borrar "${p.nombre}"?`)) return
  try {
    await eliminarProducto(p.id)
    productos.value = productos.value.filter((x) => x.id !== p.id)
  } catch (e) {
    alert(e.code === '23503' ? 'Está en un combo o promo. Sacalo de ahí primero.' : e.message)
  }
}
// --- Precios en masa: filtrar por categoría/precio actual, tildar, y
// fijar un precio nuevo o aplicar +/- % a todos los tildados de una. ---
const masaCategoriaId = ref('')
const masaPrecioFiltro = ref(null)
const masaSeleccionados = ref(new Set())
const masaModo = ref('fijo')
const masaValorFijo = ref(null)
const masaValorPct = ref(null)
const masaSigno = ref('+')
const aplicandoMasa = ref(false)

const masaFiltrados = computed(() =>
  productos.value.filter(
    (p) =>
      (!masaCategoriaId.value || p.categoria_id === masaCategoriaId.value) &&
      (masaPrecioFiltro.value === null || masaPrecioFiltro.value === '' || Number(p.precio) === Number(masaPrecioFiltro.value)),
  ),
)
const masaTodosSeleccionados = computed(
  () => masaFiltrados.value.length > 0 && masaFiltrados.value.every((p) => masaSeleccionados.value.has(p.id)),
)

function toggleMasaSeleccion(id) {
  if (masaSeleccionados.value.has(id)) masaSeleccionados.value.delete(id)
  else masaSeleccionados.value.add(id)
}
function toggleMasaTodos() {
  if (masaTodosSeleccionados.value) {
    for (const p of masaFiltrados.value) masaSeleccionados.value.delete(p.id)
  } else {
    for (const p of masaFiltrados.value) masaSeleccionados.value.add(p.id)
  }
}

async function aplicarPreciosMasa() {
  const ids = [...masaSeleccionados.value]
  if (!ids.length) return
  let calcularNuevo
  if (masaModo.value === 'fijo') {
    const nuevo = Number(masaValorFijo.value)
    if (!nuevo || nuevo <= 0) return alert('Ingresá un precio válido.')
    calcularNuevo = () => nuevo
  } else {
    const pct = Number(masaValorPct.value)
    if (!pct || pct <= 0) return alert('Ingresá un porcentaje válido.')
    const factor = 1 + (masaSigno.value === '+' ? pct : -pct) / 100
    if (factor <= 0) return alert('No se puede bajar 100% o más.')
    calcularNuevo = (actual) => Math.max(0, Math.round(Number(actual) * factor))
  }
  const verbo =
    masaModo.value === 'fijo'
      ? `Fijar el precio a $${masaValorFijo.value}`
      : `${masaSigno.value === '+' ? 'Aumentar' : 'Bajar'} ${masaValorPct.value}%`
  if (!confirm(`${verbo} en ${ids.length} producto(s)?`)) return
  aplicandoMasa.value = true
  try {
    for (const id of ids) {
      const p = productos.value.find((x) => x.id === id)
      const nuevo = calcularNuevo(p.precio)
      await actualizarProducto(id, { precio: nuevo })
      p.precio = nuevo
    }
    masaSeleccionados.value.clear()
  } catch (e) {
    alert(e.message)
  } finally {
    aplicandoMasa.value = false
  }
}

// --- Pausar en masa: filtrar por categoría/estado, tildar, y pausar o
// reactivar a todos los tildados de una. Es el switch manual `disponible`
// de siempre — "pausado" para no confundirlo con "agotado" (que va a
// significar sin stock cuando eso exista; una cosa no debe pisar la otra). ---
const pausaCategoriaId = ref('')
const pausaEstadoFiltro = ref('todos') // 'todos' | 'activo' | 'pausado'
const pausaSeleccionados = ref(new Set())
const aplicandoPausa = ref(false)

const pausaFiltrados = computed(() =>
  productos.value.filter(
    (p) =>
      (!pausaCategoriaId.value || p.categoria_id === pausaCategoriaId.value) &&
      (pausaEstadoFiltro.value === 'todos' ||
        (pausaEstadoFiltro.value === 'activo' ? p.disponible : !p.disponible)),
  ),
)
const pausaTodosSeleccionados = computed(
  () => pausaFiltrados.value.length > 0 && pausaFiltrados.value.every((p) => pausaSeleccionados.value.has(p.id)),
)

function togglePausaSeleccion(id) {
  if (pausaSeleccionados.value.has(id)) pausaSeleccionados.value.delete(id)
  else pausaSeleccionados.value.add(id)
}
function togglePausaTodos() {
  if (pausaTodosSeleccionados.value) {
    for (const p of pausaFiltrados.value) pausaSeleccionados.value.delete(p.id)
  } else {
    for (const p of pausaFiltrados.value) pausaSeleccionados.value.add(p.id)
  }
}

async function aplicarPausaMasa(nuevoValor) {
  const ids = [...pausaSeleccionados.value]
  if (!ids.length) return
  const verbo = nuevoValor ? 'Reactivar' : 'Pausar'
  if (!confirm(`${verbo} ${ids.length} producto(s)?`)) return
  aplicandoPausa.value = true
  try {
    for (const id of ids) {
      await actualizarProducto(id, { disponible: nuevoValor })
      const p = productos.value.find((x) => x.id === id)
      if (p) p.disponible = nuevoValor
    }
    pausaSeleccionados.value.clear()
  } catch (e) {
    alert(e.message)
  } finally {
    aplicandoPausa.value = false
  }
}

async function toggleCombo(c) {
  const disponible = !c.disponible
  if (disponible && c.combo_items.length === 0) {
    alert('Agregale productos antes de activarlo.')
    return
  }
  await actualizarCombo(c.id, { disponible })
  c.disponible = disponible
}
async function borrarCombo(c) {
  if (!confirm(`¿Borrar el combo "${c.nombre}"?`)) return
  try {
    await eliminarCombo(c.id)
    combos.value = combos.value.filter((x) => x.id !== c.id)
  } catch (e) {
    alert(e.message)
  }
}
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="max-w-3xl">
    <h1 class="text-2xl font-bold text-slate-900">Menú</h1>
    <p class="text-sm text-slate-500">Categorías, productos y combos de tu carta.</p>

    <div class="mt-4 flex flex-wrap gap-2">
      <button
        v-for="s in SECCIONES"
        :key="s[0]"
        type="button"
        @click="seccion = s[0]"
        :class="['chip', seccion === s[0] && 'chip-active']"
      >
        {{ s[1] }}
      </button>
    </div>

    <!-- Productos: alta y gestión 1x1 -->
    <template v-if="seccion === 'productos'">
    <form @submit.prevent="agregarCategoria" class="mt-5 flex gap-2">
      <input v-model="nuevaCategoria" type="text" placeholder="Nombre de la nueva categoría…" class="input flex-1" />
      <button type="submit" class="btn btn-dark shrink-0">+ Categoría</button>
    </form>

    <div v-for="cat in categorias" :key="cat.id" class="card mt-5 p-5">
      <div class="flex items-center justify-between gap-3">
        <template v-if="catEditandoId === cat.id">
          <input v-model="catEditandoNombre" type="text" class="input flex-1" @keyup.enter="guardarCat(cat)" />
          <div class="flex shrink-0 gap-3 text-sm">
            <button type="button" @click="guardarCat(cat)" class="font-medium t-brand">Guardar</button>
            <button type="button" @click="catEditandoId = null" class="text-slate-400">Cancelar</button>
          </div>
        </template>
        <template v-else>
          <h2 class="text-base font-bold text-slate-900">{{ cat.nombre }}</h2>
          <div class="flex shrink-0 gap-4 text-xs font-medium">
            <button type="button" @click="empezarEdicionCat(cat)" class="text-slate-500 hover:text-slate-900">Renombrar</button>
            <button type="button" @click="borrarCat(cat)" class="text-red-500 hover:text-red-700">Eliminar</button>
          </div>
        </template>
      </div>

      <ul class="mt-3 divide-y divide-slate-100">
        <li v-for="p in productosDe(cat.id)" :key="p.id" class="flex items-center justify-between gap-3 py-3">
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <p :class="['truncate text-sm font-medium', p.disponible ? 'text-slate-900' : 'text-slate-400 line-through']">
                {{ p.nombre }}
              </p>
              <span
                :class="[
                  'shrink-0 rounded-full px-2 py-0.5 text-[10px] font-medium',
                  p.estacion === 'barra' ? 'bg-purple-100 text-purple-700' : 'bg-orange-100 text-orange-700',
                ]"
              >
                {{ p.estacion }}
              </span>
              <span v-if="p.grupos_opciones?.length" class="shrink-0 text-[10px] text-slate-400">
                · {{ p.grupos_opciones.length }} grupo(s) de opciones
              </span>
            </div>
            <p v-if="p.descripcion" class="truncate text-xs text-slate-500">{{ p.descripcion }}</p>
          </div>
          <div class="flex shrink-0 items-center gap-4">
            <span class="text-sm font-semibold text-slate-900">{{ pesos(p.precio) }}</span>
            <button
              type="button" role="switch" :aria-checked="p.disponible" @click="toggleProducto(p)"
              :class="['relative h-5 w-9 rounded-full transition', p.disponible ? 'bg-brand-500' : 'bg-slate-300']"
              title="Disponible"
            >
              <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', p.disponible ? 'left-4' : 'left-0.5']" />
            </button>
            <div class="flex gap-3 text-xs font-medium">
              <button type="button" @click="editarProducto(p)" class="text-slate-500 hover:text-slate-900">Editar</button>
              <button type="button" @click="borrarProducto(p)" class="text-red-500 hover:text-red-700">Eliminar</button>
            </div>
          </div>
        </li>
      </ul>

      <button
        type="button"
        @click="nuevoProducto(cat.id)"
        class="mt-2 w-full rounded-lg border border-dashed border-slate-300 py-2 text-sm font-medium text-slate-500 hover:border-brand-300 hover:text-brand-600"
      >
        + Agregar producto
      </button>
    </div>

    <p v-if="categorias.length === 0" class="mt-6 text-slate-500">Todavía no hay categorías.</p>

    <!-- Combos -->
    <div class="mt-10">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-lg font-bold text-slate-900">Combos</h2>
          <p class="text-sm text-slate-500">Productos a precio fijo, como fernet + coca.</p>
        </div>
        <button type="button" @click="nuevoCombo" class="btn btn-dark shrink-0">+ Nuevo combo</button>
      </div>

      <ul v-if="combos.length" class="mt-4 space-y-3">
        <li v-for="c in combos" :key="c.id" class="card flex items-center justify-between gap-4 p-4">
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <p :class="['truncate font-semibold', c.disponible ? 'text-slate-900' : 'text-slate-400 line-through']">
                {{ c.nombre }}
              </p>
              <span
                :class="[
                  'shrink-0 rounded-full px-2 py-0.5 text-[10px] font-medium',
                  c.estacion === 'barra' ? 'bg-purple-100 text-purple-700' : 'bg-orange-100 text-orange-700',
                ]"
              >
                {{ c.estacion }}
              </span>
            </div>
            <p class="text-xs text-slate-500">{{ c.combo_items.length }} producto(s)</p>
          </div>
          <div class="flex shrink-0 items-center gap-4">
            <span class="text-sm font-semibold text-slate-900">{{ pesos(c.precio) }}</span>
            <button
              type="button" role="switch" :aria-checked="c.disponible" @click="toggleCombo(c)"
              :class="['relative h-5 w-9 rounded-full transition', c.disponible ? 'bg-brand-500' : 'bg-slate-300']"
              title="Disponible"
            >
              <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', c.disponible ? 'left-4' : 'left-0.5']" />
            </button>
            <div class="flex gap-3 text-xs font-medium">
              <button type="button" @click="editarCombo(c)" class="text-slate-500 hover:text-slate-900">Editar</button>
              <button type="button" @click="borrarCombo(c)" class="text-red-500 hover:text-red-700">Eliminar</button>
            </div>
          </div>
        </li>
      </ul>
      <p v-else class="mt-3 text-slate-500">Todavía no hay combos.</p>
    </div>
    </template>

    <!-- Precios en masa -->
    <div v-show="seccion === 'precios'" class="card mt-5 p-5">
      <h2 class="text-base font-bold text-slate-900">Precios en masa</h2>
      <p class="text-sm text-slate-500">
        Filtrá productos, tildá los que quieras y aplicales un precio nuevo o un ajuste porcentual a todos juntos.
      </p>

      <div class="mt-3 flex flex-wrap gap-2">
        <select v-model="masaCategoriaId" class="input w-auto">
          <option value="">Todas las categorías</option>
          <option v-for="cat in categorias" :key="cat.id" :value="cat.id">{{ cat.nombre }}</option>
        </select>
        <input
          v-model.number="masaPrecioFiltro"
          type="number" min="0" step="1"
          placeholder="Precio actual (opcional)"
          class="input w-48"
        />
      </div>

      <div class="mt-3 flex items-center justify-between text-sm">
        <label class="flex items-center gap-2">
          <input
            type="checkbox" :checked="masaTodosSeleccionados" @change="toggleMasaTodos"
            class="h-4 w-4 accent-brand-500"
          />
          Seleccionar todos ({{ masaFiltrados.length }})
        </label>
        <span class="text-slate-400">{{ masaSeleccionados.size }} elegido(s)</span>
      </div>

      <ul class="mt-2 max-h-64 space-y-0.5 overflow-y-auto rounded-lg border border-slate-200 p-2">
        <li
          v-for="p in masaFiltrados" :key="p.id"
          class="flex items-center justify-between gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-slate-50"
        >
          <label class="flex min-w-0 flex-1 items-center gap-2">
            <input
              type="checkbox" :checked="masaSeleccionados.has(p.id)" @change="toggleMasaSeleccion(p.id)"
              class="h-4 w-4 shrink-0 accent-brand-500"
            />
            <span class="truncate">{{ p.nombre }}</span>
          </label>
          <span class="shrink-0 text-xs text-slate-400">{{ pesos(p.precio) }}</span>
        </li>
        <li v-if="!masaFiltrados.length" class="p-2 text-sm text-slate-400">Ningún producto coincide con el filtro.</li>
      </ul>

      <div class="mt-3 flex flex-wrap items-center gap-2 rounded-lg bg-slate-50 p-2.5 text-sm">
        <div class="flex overflow-hidden rounded-md border border-slate-300">
          <button
            type="button" @click="masaModo = 'fijo'"
            :class="['px-2.5 py-1', masaModo === 'fijo' ? 'bg-slate-900 text-white' : 'bg-white text-slate-600']"
          >
            Fijar precio
          </button>
          <button
            type="button" @click="masaModo = 'pct'"
            :class="['border-l border-slate-300 px-2.5 py-1', masaModo === 'pct' ? 'bg-slate-900 text-white' : 'bg-white text-slate-600']"
          >
            Ajustar %
          </button>
        </div>

        <template v-if="masaModo === 'fijo'">
          <span class="text-slate-500">$</span>
          <input v-model.number="masaValorFijo" type="number" min="0" step="1" placeholder="9000" class="input w-28 py-1" />
        </template>
        <template v-else>
          <div class="flex overflow-hidden rounded-md border border-slate-300">
            <button
              type="button" @click="masaSigno = '+'"
              :class="['px-2.5 py-1', masaSigno === '+' ? 'bg-slate-900 text-white' : 'bg-white text-slate-600']"
            >
              +
            </button>
            <button
              type="button" @click="masaSigno = '-'"
              :class="['border-l border-slate-300 px-2.5 py-1', masaSigno === '-' ? 'bg-slate-900 text-white' : 'bg-white text-slate-600']"
            >
              −
            </button>
          </div>
          <input v-model.number="masaValorPct" type="number" min="0" step="1" placeholder="10" class="input w-20 py-1" />
          <span class="text-slate-500">%</span>
        </template>

        <button
          type="button"
          :disabled="!masaSeleccionados.size || aplicandoMasa || (masaModo === 'fijo' ? !masaValorFijo : !masaValorPct)"
          @click="aplicarPreciosMasa"
          class="btn btn-brand px-3 py-1 text-xs"
        >
          {{ aplicandoMasa ? 'Aplicando…' : `Aplicar a ${masaSeleccionados.size} producto(s)` }}
        </button>
      </div>
    </div>

    <!-- Pausar en masa -->
    <div v-show="seccion === 'pausar'" class="card mt-5 p-5">
      <h2 class="text-base font-bold text-slate-900">Pausar productos en masa</h2>
      <p class="text-sm text-slate-500">
        Filtrá productos, tildá los que quieras y pausalos o reactivalos a todos juntos —
        sin tocar nada más (útil para algo temporal, como si falta alguien en la cocina).
      </p>

      <div class="mt-3 flex flex-wrap gap-2">
        <select v-model="pausaCategoriaId" class="input w-auto">
          <option value="">Todas las categorías</option>
          <option v-for="cat in categorias" :key="cat.id" :value="cat.id">{{ cat.nombre }}</option>
        </select>
        <div class="flex overflow-hidden rounded-md border border-slate-300">
          <button
            type="button" @click="pausaEstadoFiltro = 'todos'"
            :class="['px-2.5 py-1 text-sm', pausaEstadoFiltro === 'todos' ? 'bg-slate-900 text-white' : 'bg-white text-slate-600']"
          >
            Todos
          </button>
          <button
            type="button" @click="pausaEstadoFiltro = 'activo'"
            :class="['border-l border-slate-300 px-2.5 py-1 text-sm', pausaEstadoFiltro === 'activo' ? 'bg-slate-900 text-white' : 'bg-white text-slate-600']"
          >
            Activos
          </button>
          <button
            type="button" @click="pausaEstadoFiltro = 'pausado'"
            :class="['border-l border-slate-300 px-2.5 py-1 text-sm', pausaEstadoFiltro === 'pausado' ? 'bg-slate-900 text-white' : 'bg-white text-slate-600']"
          >
            Pausados
          </button>
        </div>
      </div>

      <div class="mt-3 flex items-center justify-between text-sm">
        <label class="flex items-center gap-2">
          <input
            type="checkbox" :checked="pausaTodosSeleccionados" @change="togglePausaTodos"
            class="h-4 w-4 accent-brand-500"
          />
          Seleccionar todos ({{ pausaFiltrados.length }})
        </label>
        <span class="text-slate-400">{{ pausaSeleccionados.size }} elegido(s)</span>
      </div>

      <ul class="mt-2 max-h-64 space-y-0.5 overflow-y-auto rounded-lg border border-slate-200 p-2">
        <li
          v-for="p in pausaFiltrados" :key="p.id"
          class="flex items-center justify-between gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-slate-50"
        >
          <label class="flex min-w-0 flex-1 items-center gap-2">
            <input
              type="checkbox" :checked="pausaSeleccionados.has(p.id)" @change="togglePausaSeleccion(p.id)"
              class="h-4 w-4 shrink-0 accent-brand-500"
            />
            <span :class="['truncate', !p.disponible && 'text-slate-400 line-through']">{{ p.nombre }}</span>
          </label>
          <span :class="['shrink-0 text-xs', p.disponible ? 'text-emerald-600' : 'text-slate-400']">
            {{ p.disponible ? 'Activo' : 'Pausado' }}
          </span>
        </li>
        <li v-if="!pausaFiltrados.length" class="p-2 text-sm text-slate-400">Ningún producto coincide con el filtro.</li>
      </ul>

      <div class="mt-3 flex flex-wrap items-center gap-2 rounded-lg bg-slate-50 p-2.5 text-sm">
        <span class="text-slate-500">{{ pausaSeleccionados.size }} seleccionado(s)</span>
        <button
          type="button"
          :disabled="!pausaSeleccionados.size || aplicandoPausa"
          @click="aplicarPausaMasa(true)"
          class="btn btn-brand px-3 py-1 text-xs"
        >
          Reactivar
        </button>
        <button
          type="button"
          :disabled="!pausaSeleccionados.size || aplicandoPausa"
          @click="aplicarPausaMasa(false)"
          class="btn btn-dark px-3 py-1 text-xs"
        >
          Pausar
        </button>
      </div>
    </div>

    <!-- Stock: pendiente (fase futura) -->
    <div v-show="seccion === 'stock'" class="card mt-5 p-5 text-center">
      <h2 class="text-base font-bold text-slate-900">Stock en masa</h2>
      <p class="mx-auto mt-1 max-w-md text-sm text-slate-500">
        Todavía no está construido. Va a permitir cargar cantidad real y
        descontarla en cada pedido — por ahora el control de disponibilidad
        es manual (el switch de cada producto).
      </p>
    </div>
  </section>
</template>
