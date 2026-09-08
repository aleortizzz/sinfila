<script setup>
import { ref, watch } from 'vue'
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
  </section>
</template>
