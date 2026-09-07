<script setup>
import { ref, reactive, computed, watch } from 'vue'
import {
  obtenerCategoriasAdmin,
  obtenerProductosAdmin,
  crearCategoria,
  actualizarCategoria,
  eliminarCategoria,
  crearProducto,
  actualizarProducto,
  eliminarProducto,
  crearGrupoOpciones,
  actualizarGrupoOpciones,
  eliminarGrupoOpciones,
  crearOpcion,
  actualizarOpcion,
  eliminarOpcion,
  obtenerCombosAdmin,
  crearCombo,
  actualizarCombo,
  eliminarCombo,
  agregarItemCombo,
  quitarItemCombo,
} from '../../lib/admin'

const props = defineProps({ local: Object })

const cargando = ref(true)
const error = ref(null)
const categorias = ref([])
const productos = ref([])
const combos = ref([])

const nuevaCategoriaNombre = ref('')
const categoriaEditandoId = ref(null)
const categoriaEditandoNombre = ref('')

const mostrarFormProducto = ref(null) // id de la categoría cuyo form está abierto
const productoEditandoId = ref(null)
const formProducto = reactive({ nombre: '', descripcion: '', precio: '', foto_url: '', estacion: 'barra' })
const productoEnEdicion = computed(() => productos.value.find((p) => p.id === productoEditandoId.value))

const nuevoGrupoNombre = ref('')
const nuevoGrupoObligatorio = ref(true)
const nuevaOpcion = reactive({}) // { [grupoId]: { nombre, precioAjuste } }

const mostrarFormCombo = ref(null) // 'nuevo' | id del combo en edición | null
const formCombo = reactive({ nombre: '', descripcion: '', precio: '', estacion: 'barra' })
// Selección del "agregar producto al combo" — una entrada por combo abierto.
const nuevoItem = reactive({}) // { [comboId]: { productoId, cantidad } }

// Armado de un combo NUEVO: se eligen los productos antes de crearlo (no
// se puede publicar un combo vacío). El precio se sugiere solo (suma de
// los productos elegidos) y se puede pisar a mano.
const nuevoComboItems = ref([]) // [{ productoId, nombre, precio, cantidad }]
const nuevoComboSel = reactive({ productoId: '', cantidad: 1 })
const precioComboTocado = ref(false)

const precioSugeridoNuevo = computed(() =>
  nuevoComboItems.value.reduce((s, i) => s + i.precio * i.cantidad, 0),
)

function productosParaNuevoCombo() {
  const yaIncluidos = new Set(nuevoComboItems.value.map((i) => i.productoId))
  return productos.value.filter((p) => !yaIncluidos.has(p.id))
}

function agregarItemDraft() {
  const p = productos.value.find((x) => x.id === nuevoComboSel.productoId)
  if (!p) return
  nuevoComboItems.value.push({ productoId: p.id, nombre: p.nombre, precio: p.precio, cantidad: nuevoComboSel.cantidad || 1 })
  nuevoComboSel.productoId = ''
  nuevoComboSel.cantidad = 1
  if (!precioComboTocado.value) formCombo.precio = precioSugeridoNuevo.value
}

function quitarItemDraft(idx) {
  nuevoComboItems.value.splice(idx, 1)
  if (!precioComboTocado.value) formCombo.precio = precioSugeridoNuevo.value
}

let cargado = false
watch(
  () => props.local,
  (val) => {
    if (val && !cargado) {
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
    cmbs.forEach((c) => (nuevoItem[c.id] = { productoId: '', cantidad: 1 }))
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

function productosPorCategoria(categoriaId) {
  return productos.value.filter((p) => p.categoria_id === categoriaId)
}

async function agregarCategoria() {
  if (!nuevaCategoriaNombre.value.trim()) return
  const cat = await crearCategoria(props.local.id, nuevaCategoriaNombre.value.trim(), categorias.value.length)
  categorias.value.push(cat)
  nuevaCategoriaNombre.value = ''
}

function empezarEdicionCategoria(cat) {
  categoriaEditandoId.value = cat.id
  categoriaEditandoNombre.value = cat.nombre
}

async function guardarNombreCategoria(cat) {
  if (!categoriaEditandoNombre.value.trim()) return
  await actualizarCategoria(cat.id, { nombre: categoriaEditandoNombre.value.trim() })
  cat.nombre = categoriaEditandoNombre.value.trim()
  categoriaEditandoId.value = null
}

async function borrarCategoria(cat) {
  if (!confirm(`¿Borrar la categoría "${cat.nombre}"?`)) return
  try {
    await eliminarCategoria(cat.id)
    categorias.value = categorias.value.filter((c) => c.id !== cat.id)
  } catch (e) {
    if (e.code === '23503') {
      alert('No se puede borrar: todavía tiene productos. Movelos o borralos primero.')
    } else {
      alert(e.message)
    }
  }
}

function resetFormProducto() {
  formProducto.nombre = ''
  formProducto.descripcion = ''
  formProducto.precio = ''
  formProducto.foto_url = ''
  formProducto.estacion = 'barra'
}

function abrirFormNuevoProducto(categoriaId) {
  productoEditandoId.value = null
  resetFormProducto()
  mostrarFormProducto.value = categoriaId
}

function editarProducto(p) {
  productoEditandoId.value = p.id
  formProducto.nombre = p.nombre
  formProducto.descripcion = p.descripcion ?? ''
  formProducto.precio = p.precio
  formProducto.foto_url = p.foto_url ?? ''
  formProducto.estacion = p.estacion
  mostrarFormProducto.value = p.categoria_id
  p.grupos_opciones.forEach((g) => {
    if (!nuevaOpcion[g.id]) nuevaOpcion[g.id] = { nombre: '', precioAjuste: 0 }
  })
}

// --- Grupos de opciones / opciones (armado) ---

async function agregarGrupo(producto) {
  if (!nuevoGrupoNombre.value.trim()) return
  const grupo = await crearGrupoOpciones(
    producto.id,
    nuevoGrupoNombre.value.trim(),
    nuevoGrupoObligatorio.value,
    producto.grupos_opciones.length,
  )
  producto.grupos_opciones.push(grupo)
  nuevaOpcion[grupo.id] = { nombre: '', precioAjuste: 0 }
  nuevoGrupoNombre.value = ''
  nuevoGrupoObligatorio.value = true
}

async function guardarGrupo(grupo) {
  try {
    await actualizarGrupoOpciones(grupo.id, { nombre: grupo.nombre, obligatorio: grupo.obligatorio })
  } catch (e) {
    alert(e.message)
  }
}

async function borrarGrupo(producto, grupo) {
  if (!confirm(`¿Borrar el grupo "${grupo.nombre}" y todas sus opciones?`)) return
  await eliminarGrupoOpciones(grupo.id)
  producto.grupos_opciones = producto.grupos_opciones.filter((g) => g.id !== grupo.id)
}

async function agregarOpcion(grupo) {
  const sel = nuevaOpcion[grupo.id]
  if (!sel?.nombre?.trim()) return
  const op = await crearOpcion(grupo.id, sel.nombre.trim(), Number(sel.precioAjuste) || 0, grupo.opciones.length)
  grupo.opciones.push(op)
  nuevaOpcion[grupo.id] = { nombre: '', precioAjuste: 0 }
}

async function guardarOpcion(opcion) {
  try {
    await actualizarOpcion(opcion.id, { nombre: opcion.nombre, precio_ajuste: Number(opcion.precio_ajuste) || 0 })
  } catch (e) {
    alert(e.message)
  }
}

async function borrarOpcion(grupo, opcion) {
  await eliminarOpcion(opcion.id)
  grupo.opciones = grupo.opciones.filter((o) => o.id !== opcion.id)
}

function cancelarFormProducto() {
  mostrarFormProducto.value = null
  productoEditandoId.value = null
}

async function guardarProducto(categoriaId) {
  if (!formProducto.nombre.trim() || formProducto.precio === '') return
  const payload = {
    nombre: formProducto.nombre.trim(),
    descripcion: formProducto.descripcion.trim() || null,
    precio: Number(formProducto.precio),
    foto_url: formProducto.foto_url.trim() || null,
    estacion: formProducto.estacion,
    categoria_id: categoriaId,
    local_id: props.local.id,
  }
  try {
    if (productoEditandoId.value) {
      await actualizarProducto(productoEditandoId.value, payload)
      const idx = productos.value.findIndex((p) => p.id === productoEditandoId.value)
      productos.value[idx] = { ...productos.value[idx], ...payload }
    } else {
      const nuevo = await crearProducto(payload)
      productos.value.push({ ...nuevo, grupos_opciones: [] })
    }
    cancelarFormProducto()
  } catch (e) {
    alert(e.message)
  }
}

async function toggleDisponible(p) {
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
    if (e.code === '23503') {
      alert('No se puede borrar: está usado en un combo o una promo. Sacalo de ahí primero.')
    } else {
      alert(e.message)
    }
  }
}

// --- Combos ---

function resetFormCombo() {
  formCombo.nombre = ''
  formCombo.descripcion = ''
  formCombo.precio = ''
  formCombo.estacion = 'barra'
}

function abrirFormNuevoCombo() {
  resetFormCombo()
  nuevoComboItems.value = []
  precioComboTocado.value = false
  mostrarFormCombo.value = 'nuevo'
}

function editarCombo(combo) {
  formCombo.nombre = combo.nombre
  formCombo.descripcion = combo.descripcion ?? ''
  formCombo.precio = combo.precio
  formCombo.estacion = combo.estacion
  mostrarFormCombo.value = combo.id
}

function cancelarFormCombo() {
  mostrarFormCombo.value = null
}

async function guardarCombo() {
  if (!formCombo.nombre.trim() || formCombo.precio === '') return
  const payload = {
    nombre: formCombo.nombre.trim(),
    descripcion: formCombo.descripcion.trim() || null,
    precio: Number(formCombo.precio),
    estacion: formCombo.estacion,
  }
  try {
    if (mostrarFormCombo.value === 'nuevo') {
      if (nuevoComboItems.value.length === 0) {
        alert('Agregá al menos un producto al combo antes de crearlo.')
        return
      }
      const nuevo = await crearCombo({
        ...payload,
        local_id: props.local.id,
        orden: combos.value.length,
        disponible: false, // lo activás vos cuando quieras publicarlo
      })
      for (const draft of nuevoComboItems.value) {
        const item = await agregarItemCombo(nuevo.id, draft.productoId, draft.cantidad)
        nuevo.combo_items.push(item)
      }
      combos.value.push(nuevo)
      nuevoItem[nuevo.id] = { productoId: '', cantidad: 1 }
    } else {
      const id = mostrarFormCombo.value
      await actualizarCombo(id, payload)
      const idx = combos.value.findIndex((c) => c.id === id)
      combos.value[idx] = { ...combos.value[idx], ...payload }
    }
    cancelarFormCombo()
  } catch (e) {
    alert(e.message)
  }
}

async function toggleComboDisponible(combo) {
  const disponible = !combo.disponible
  if (disponible && combo.combo_items.length === 0) {
    alert('Agregale productos antes de activarlo — no se puede vender un combo vacío.')
    return
  }
  await actualizarCombo(combo.id, { disponible })
  combo.disponible = disponible
}

function precioSugeridoActual(combo) {
  return combo.combo_items.reduce((s, i) => {
    const p = productos.value.find((x) => x.id === i.producto_id)
    return s + (p ? p.precio * i.cantidad : 0)
  }, 0)
}

async function usarPrecioSugerido(combo) {
  const sugerido = precioSugeridoActual(combo)
  await actualizarCombo(combo.id, { precio: sugerido })
  combo.precio = sugerido
}

async function borrarCombo(combo) {
  if (!confirm(`¿Borrar el combo "${combo.nombre}"?`)) return
  try {
    await eliminarCombo(combo.id)
    combos.value = combos.value.filter((c) => c.id !== combo.id)
  } catch (e) {
    alert(e.message)
  }
}

function productosDisponiblesParaCombo(combo) {
  const yaIncluidos = new Set(combo.combo_items.map((i) => i.producto_id))
  return productos.value.filter((p) => !yaIncluidos.has(p.id))
}

async function agregarItemAlCombo(combo) {
  const sel = nuevoItem[combo.id]
  if (!sel?.productoId) return
  const item = await agregarItemCombo(combo.id, sel.productoId, sel.cantidad || 1)
  combo.combo_items.push(item)
  nuevoItem[combo.id] = { productoId: '', cantidad: 1 }
}

async function quitarItemDeCombo(item, combo) {
  await quitarItemCombo(item.id)
  combo.combo_items = combo.combo_items.filter((i) => i.id !== item.id)
  // Si se quedó sin productos, lo apagamos: no puede seguir a la venta vacío.
  if (combo.combo_items.length === 0 && combo.disponible) {
    await actualizarCombo(combo.id, { disponible: false })
    combo.disponible = false
  }
}
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="max-w-3xl">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-semibold text-slate-900">Menú</h1>
        <p class="text-sm text-slate-500">Categorías y productos de tu carta.</p>
      </div>
    </div>

    <form @submit.prevent="agregarCategoria" class="mt-5 flex gap-2">
      <input
        v-model="nuevaCategoriaNombre"
        type="text"
        placeholder="Nombre de la nueva categoría…"
        class="flex-1 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm shadow-sm focus:border-indigo-400 focus:outline-none focus:ring-1 focus:ring-indigo-400"
      />
      <button type="submit" class="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800">
        + Categoría
      </button>
    </form>

    <div v-for="cat in categorias" :key="cat.id" class="mt-5 rounded-xl border border-slate-200 bg-white p-5 shadow-sm">
      <div class="flex items-center justify-between">
        <template v-if="categoriaEditandoId === cat.id">
          <input
            v-model="categoriaEditandoNombre"
            type="text"
            class="rounded-md border border-slate-300 px-2 py-1 text-sm"
            @keyup.enter="guardarNombreCategoria(cat)"
          />
          <div class="flex gap-3 text-sm">
            <button type="button" @click="guardarNombreCategoria(cat)" class="font-medium text-indigo-600">Guardar</button>
            <button type="button" @click="categoriaEditandoId = null" class="text-slate-400">Cancelar</button>
          </div>
        </template>
        <template v-else>
          <h2 class="text-base font-semibold text-slate-900">{{ cat.nombre }}</h2>
          <div class="flex gap-4 text-xs font-medium">
            <button type="button" @click="empezarEdicionCategoria(cat)" class="text-slate-500 hover:text-slate-900">Editar</button>
            <button type="button" @click="borrarCategoria(cat)" class="text-red-500 hover:text-red-700">Eliminar</button>
          </div>
        </template>
      </div>

      <ul class="mt-3 divide-y divide-slate-100">
        <li v-for="p in productosPorCategoria(cat.id)" :key="p.id" class="flex items-center justify-between gap-3 py-3">
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <p :class="['truncate text-sm font-medium', !p.disponible ? 'text-slate-400 line-through' : 'text-slate-900']">
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
            </div>
            <p v-if="p.descripcion" class="truncate text-xs text-slate-500">{{ p.descripcion }}</p>
            <p v-for="g in p.grupos_opciones" :key="g.id" class="truncate text-xs text-slate-400">
              {{ g.nombre }}:
              {{ g.opciones.map((o) => (o.precio_ajuste ? `${o.nombre} (+$${o.precio_ajuste})` : o.nombre)).join(', ') }}
            </p>
          </div>
          <div class="flex shrink-0 items-center gap-4">
            <span class="text-sm font-semibold text-slate-900">${{ p.precio }}</span>

            <button
              type="button"
              role="switch"
              :aria-checked="p.disponible"
              @click="toggleDisponible(p)"
              :class="['relative h-5 w-9 rounded-full transition', p.disponible ? 'bg-indigo-500' : 'bg-slate-300']"
              title="Disponible"
            >
              <span
                :class="[
                  'absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition',
                  p.disponible ? 'left-4' : 'left-0.5',
                ]"
              />
            </button>

            <div class="flex gap-3 text-xs font-medium">
              <button type="button" @click="editarProducto(p)" class="text-slate-500 hover:text-slate-900">Editar</button>
              <button type="button" @click="borrarProducto(p)" class="text-red-500 hover:text-red-700">Eliminar</button>
            </div>
          </div>
        </li>
      </ul>

      <button
        v-if="mostrarFormProducto !== cat.id"
        type="button"
        @click="abrirFormNuevoProducto(cat.id)"
        class="mt-2 w-full rounded-lg border border-dashed border-slate-300 py-2 text-sm font-medium text-slate-500 hover:border-indigo-300 hover:text-indigo-600"
      >
        + Agregar producto
      </button>

      <form v-else @submit.prevent="guardarProducto(cat.id)" class="mt-3 space-y-2 rounded-lg bg-slate-50 p-4">
        <input v-model="formProducto.nombre" type="text" placeholder="Nombre" class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm" />
        <input v-model="formProducto.descripcion" type="text" placeholder="Descripción (opcional)" class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm" />
        <div class="flex gap-2">
          <input v-model="formProducto.precio" type="number" min="0" step="1" placeholder="Precio" class="w-1/2 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm" />
          <select v-model="formProducto.estacion" class="w-1/2 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm">
            <option value="barra">Barra</option>
            <option value="cocina">Cocina</option>
          </select>
        </div>
        <input v-model="formProducto.foto_url" type="text" placeholder="URL de la foto (opcional)" class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm" />
        <div class="flex gap-2 pt-1">
          <button type="submit" class="rounded-md bg-slate-900 px-4 py-1.5 text-sm font-medium text-white hover:bg-slate-800">
            {{ productoEditandoId ? 'Guardar cambios' : 'Crear producto' }}
          </button>
          <button type="button" @click="cancelarFormProducto" class="rounded-md border border-slate-300 px-4 py-1.5 text-sm text-slate-600">
            Cancelar
          </button>
        </div>

        <!-- Armado: solo tiene sentido con el producto ya creado. -->
        <div v-if="productoEnEdicion" class="mt-3 border-t border-slate-200 pt-3">
          <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
            Armado (grupos de opciones)
          </p>

          <div v-for="grupo in productoEnEdicion.grupos_opciones" :key="grupo.id" class="mt-2 rounded-md border border-slate-200 bg-white p-3">
            <div class="flex items-center gap-2">
              <input
                v-model="grupo.nombre"
                type="text"
                @blur="guardarGrupo(grupo)"
                class="flex-1 rounded-md border border-slate-300 px-2 py-1 text-sm"
              />
              <label class="flex items-center gap-1 text-xs text-slate-500">
                <input type="checkbox" v-model="grupo.obligatorio" @change="guardarGrupo(grupo)" />
                Obligatorio
              </label>
              <button type="button" @click="borrarGrupo(productoEnEdicion, grupo)" class="text-xs font-medium text-red-500 hover:text-red-700">
                Eliminar grupo
              </button>
            </div>

            <ul class="mt-2 space-y-1">
              <li v-for="opcion in grupo.opciones" :key="opcion.id" class="flex items-center gap-2">
                <input
                  v-model="opcion.nombre"
                  type="text"
                  @blur="guardarOpcion(opcion)"
                  class="flex-1 rounded-md border border-slate-300 px-2 py-1 text-sm"
                />
                <span class="text-xs text-slate-400">+$</span>
                <input
                  v-model="opcion.precio_ajuste"
                  type="number"
                  step="1"
                  @blur="guardarOpcion(opcion)"
                  class="w-20 rounded-md border border-slate-300 px-2 py-1 text-sm"
                />
                <button type="button" @click="borrarOpcion(grupo, opcion)" class="text-xs text-red-500 hover:text-red-700">✕</button>
              </li>
            </ul>

            <div v-if="nuevaOpcion[grupo.id]" class="mt-2 flex items-center gap-2">
              <input
                v-model="nuevaOpcion[grupo.id].nombre"
                type="text"
                placeholder="Nueva opción (ej. Con cheddar y bacon)"
                class="flex-1 rounded-md border border-slate-300 px-2 py-1 text-sm"
              />
              <span class="text-xs text-slate-400">+$</span>
              <input v-model.number="nuevaOpcion[grupo.id].precioAjuste" type="number" step="1" class="w-20 rounded-md border border-slate-300 px-2 py-1 text-sm" />
              <button type="button" @click="agregarOpcion(grupo)" class="rounded-md bg-slate-900 px-2 py-1 text-xs font-medium text-white hover:bg-slate-800">
                + Opción
              </button>
            </div>
          </div>

          <div class="mt-2 flex items-center gap-2">
            <input v-model="nuevoGrupoNombre" type="text" placeholder="Nuevo grupo (ej. Elegí el relleno)" class="flex-1 rounded-md border border-slate-300 px-2 py-1 text-sm" />
            <label class="flex items-center gap-1 text-xs text-slate-500">
              <input type="checkbox" v-model="nuevoGrupoObligatorio" />
              Obligatorio
            </label>
            <button type="button" @click="agregarGrupo(productoEnEdicion)" class="rounded-md border border-slate-300 px-3 py-1 text-xs font-medium text-slate-700 hover:bg-slate-100">
              + Grupo
            </button>
          </div>
        </div>
      </form>
    </div>

    <p v-if="categorias.length === 0" class="mt-6 text-slate-500">Todavía no hay categorías.</p>

    <!-- Combos -->
    <div class="mt-10">
      <h2 class="text-lg font-semibold text-slate-900">Combos</h2>
      <p class="text-sm text-slate-500">Combos de productos a precio fijo, como fernet + coca.</p>

      <button
        v-if="mostrarFormCombo === null"
        type="button"
        @click="abrirFormNuevoCombo"
        class="mt-3 w-full rounded-lg border border-dashed border-slate-300 py-2 text-sm font-medium text-slate-500 hover:border-indigo-300 hover:text-indigo-600"
      >
        + Nuevo combo
      </button>

      <form
        v-if="mostrarFormCombo === 'nuevo'"
        @submit.prevent="guardarCombo"
        class="mt-3 space-y-2 rounded-lg bg-slate-50 p-4"
      >
        <input v-model="formCombo.nombre" type="text" placeholder="Nombre del combo" class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm" />
        <input v-model="formCombo.descripcion" type="text" placeholder="Descripción (opcional)" class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm" />
        <select v-model="formCombo.estacion" class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm">
          <option value="barra">Barra</option>
          <option value="cocina">Cocina</option>
        </select>

        <p class="pt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">Productos del combo</p>

        <ul v-if="nuevoComboItems.length" class="space-y-1">
          <li v-for="(item, idx) in nuevoComboItems" :key="idx" class="flex items-center justify-between rounded-md bg-white px-3 py-1.5 text-sm">
            <span>{{ item.cantidad }}× {{ item.nombre }} <span class="text-slate-400">(${{ item.precio }} c/u)</span></span>
            <button type="button" @click="quitarItemDraft(idx)" class="text-xs font-medium text-red-500 hover:text-red-700">Quitar</button>
          </li>
        </ul>
        <p v-else class="text-sm text-slate-400">Todavía no elegiste ningún producto.</p>

        <div class="flex gap-2">
          <select v-model="nuevoComboSel.productoId" class="flex-1 rounded-md border border-slate-300 bg-white px-2 py-1.5 text-sm">
            <option value="" disabled>Elegí un producto…</option>
            <option v-for="p in productosParaNuevoCombo()" :key="p.id" :value="p.id">{{ p.nombre }} (${{ p.precio }})</option>
          </select>
          <input v-model.number="nuevoComboSel.cantidad" type="number" min="1" class="w-16 rounded-md border border-slate-300 bg-white px-2 py-1.5 text-sm" />
          <button type="button" @click="agregarItemDraft" class="rounded-md border border-slate-300 bg-white px-3 py-1.5 text-xs font-medium text-slate-700 hover:bg-slate-100">
            + Agregar
          </button>
        </div>

        <div class="flex items-center gap-2 pt-1">
          <span v-if="nuevoComboItems.length" class="text-sm text-slate-400 line-through">${{ precioSugeridoNuevo }}</span>
          <input
            v-model="formCombo.precio"
            @input="precioComboTocado = true"
            type="number"
            min="0"
            step="1"
            placeholder="Precio del combo"
            class="w-32 rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-semibold"
          />
          <span class="text-xs text-slate-400">precio real del combo</span>
        </div>

        <div class="flex gap-2 pt-1">
          <button type="submit" class="rounded-md bg-slate-900 px-4 py-1.5 text-sm font-medium text-white hover:bg-slate-800">Crear combo</button>
          <button type="button" @click="cancelarFormCombo" class="rounded-md border border-slate-300 px-4 py-1.5 text-sm text-slate-600">Cancelar</button>
        </div>
      </form>

      <div v-for="combo in combos" :key="combo.id" class="mt-4 rounded-xl border border-slate-200 bg-white p-5 shadow-sm">
        <div v-if="mostrarFormCombo === combo.id">
          <form @submit.prevent="guardarCombo" class="space-y-2">
            <input v-model="formCombo.nombre" type="text" placeholder="Nombre del combo" class="w-full rounded-md border border-slate-300 px-3 py-2 text-sm" />
            <input v-model="formCombo.descripcion" type="text" placeholder="Descripción (opcional)" class="w-full rounded-md border border-slate-300 px-3 py-2 text-sm" />
            <div class="flex gap-2">
              <input v-model="formCombo.precio" type="number" min="0" step="1" placeholder="Precio" class="w-1/2 rounded-md border border-slate-300 px-3 py-2 text-sm" />
              <select v-model="formCombo.estacion" class="w-1/2 rounded-md border border-slate-300 px-3 py-2 text-sm">
                <option value="barra">Barra</option>
                <option value="cocina">Cocina</option>
              </select>
            </div>
            <div class="flex gap-2 pt-1">
              <button type="submit" class="rounded-md bg-slate-900 px-4 py-1.5 text-sm font-medium text-white hover:bg-slate-800">Guardar cambios</button>
              <button type="button" @click="cancelarFormCombo" class="rounded-md border border-slate-300 px-4 py-1.5 text-sm text-slate-600">Cancelar</button>
            </div>
          </form>
        </div>

        <template v-else>
          <div class="flex items-center justify-between">
            <div>
              <div class="flex items-center gap-2">
                <h3 :class="['text-base font-semibold', combo.disponible ? 'text-slate-900' : 'text-slate-400 line-through']">
                  {{ combo.nombre }}
                </h3>
                <span
                  :class="[
                    'rounded-full px-2 py-0.5 text-[10px] font-medium',
                    combo.estacion === 'barra' ? 'bg-purple-100 text-purple-700' : 'bg-orange-100 text-orange-700',
                  ]"
                >
                  {{ combo.estacion }}
                </span>
              </div>
              <p v-if="combo.descripcion" class="text-xs text-slate-500">{{ combo.descripcion }}</p>
            </div>
            <div class="flex items-center gap-4">
              <span class="text-sm font-semibold text-slate-900">${{ combo.precio }}</span>

              <button
                type="button"
                role="switch"
                :aria-checked="combo.disponible"
                @click="toggleComboDisponible(combo)"
                :class="['relative h-5 w-9 rounded-full transition', combo.disponible ? 'bg-indigo-500' : 'bg-slate-300']"
                title="Disponible"
              >
                <span
                  :class="[
                    'absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition',
                    combo.disponible ? 'left-4' : 'left-0.5',
                  ]"
                />
              </button>

              <div class="flex gap-3 text-xs font-medium">
                <button type="button" @click="editarCombo(combo)" class="text-slate-500 hover:text-slate-900">Editar</button>
                <button type="button" @click="borrarCombo(combo)" class="text-red-500 hover:text-red-700">Eliminar</button>
              </div>
            </div>
          </div>

          <ul class="mt-3 divide-y divide-slate-100">
            <li v-for="item in combo.combo_items" :key="item.id" class="flex items-center justify-between py-2 text-sm">
              <span>{{ item.cantidad }}× {{ item.productos.nombre }}</span>
              <button type="button" @click="quitarItemDeCombo(item, combo)" class="text-xs font-medium text-red-500 hover:text-red-700">
                Quitar
              </button>
            </li>
            <li v-if="combo.combo_items.length === 0" class="py-2 text-sm text-slate-400">
              Todavía no tiene productos — está vacío.
            </li>
          </ul>

          <div v-if="nuevoItem[combo.id]" class="mt-2 flex gap-2">
            <select v-model="nuevoItem[combo.id].productoId" class="flex-1 rounded-md border border-slate-300 px-2 py-1.5 text-sm">
              <option value="" disabled>Agregar producto…</option>
              <option v-for="p in productosDisponiblesParaCombo(combo)" :key="p.id" :value="p.id">{{ p.nombre }}</option>
            </select>
            <input v-model.number="nuevoItem[combo.id].cantidad" type="number" min="1" class="w-16 rounded-md border border-slate-300 px-2 py-1.5 text-sm" />
            <button type="button" @click="agregarItemAlCombo(combo)" class="rounded-md bg-slate-900 px-3 py-1.5 text-xs font-medium text-white hover:bg-slate-800">
              Agregar
            </button>
          </div>

          <p v-if="combo.combo_items.length && precioSugeridoActual(combo) !== combo.precio" class="mt-2 text-xs text-slate-500">
            Suma de los productos: <span class="line-through">${{ precioSugeridoActual(combo) }}</span>
            <button type="button" @click="usarPrecioSugerido(combo)" class="ml-1 font-medium text-indigo-600 hover:text-indigo-800">
              usar este precio
            </button>
          </p>
        </template>
      </div>

      <p v-if="combos.length === 0 && mostrarFormCombo === null" class="mt-3 text-slate-500">Todavía no hay combos.</p>
    </div>
  </section>
</template>
