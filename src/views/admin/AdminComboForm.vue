<script setup>
import { ref, reactive, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  obtenerProductosAdmin,
  obtenerComboAdmin,
  crearCombo,
  actualizarCombo,
  agregarItemCombo,
  quitarItemCombo,
} from '../../lib/admin'
import { pesos } from '../../lib/formato'

const props = defineProps({ local: Object })
const route = useRoute()
const router = useRouter()

const comboId = computed(() => route.params.comboId || null)
const esNuevo = computed(() => !comboId.value)

const cargando = ref(true)
const error = ref(null)
const guardando = ref(false)
const estado = ref(null)

const productos = ref([])
const form = reactive({ nombre: '', descripcion: '', estacion: 'barra', precio: '', disponible: false })

// Ítems del combo. En "nuevo" son un borrador local; en "edición" son filas
// reales de combo_items (alta/baja inmediata).
const items = ref([]) // { id?, producto_id, nombre, precio, cantidad }
const sel = reactive({ producto_id: '', cantidad: 1 })
const precioTocado = ref(false)

const sugerido = computed(() =>
  items.value.reduce((s, i) => s + Number(i.precio) * i.cantidad, 0),
)
const disponiblesParaAgregar = computed(() => {
  const ya = new Set(items.value.map((i) => i.producto_id))
  return productos.value.filter((p) => !ya.has(p.id))
})

let arrancado = false
watch(
  () => props.local,
  (l) => {
    if (!l || arrancado) return
    arrancado = true
    cargar()
  },
  { immediate: true },
)
watch(
  () => route.params.comboId,
  () => {
    if (arrancado) cargar()
  },
)

async function cargar() {
  cargando.value = true
  try {
    productos.value = await obtenerProductosAdmin(props.local.id)
    if (!esNuevo.value) {
      const c = await obtenerComboAdmin(comboId.value)
      form.nombre = c.nombre
      form.descripcion = c.descripcion ?? ''
      form.estacion = c.estacion
      form.precio = c.precio
      form.disponible = c.disponible
      items.value = (c.combo_items ?? []).map((ci) => ({
        id: ci.id,
        producto_id: ci.producto_id,
        nombre: ci.productos?.nombre ?? '—',
        precio: ci.productos?.precio ?? 0,
        cantidad: ci.cantidad,
      }))
    }
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

function recalcularPrecioSiCorresponde() {
  if (!precioTocado.value) form.precio = sugerido.value
}

async function agregarItem() {
  const p = productos.value.find((x) => x.id === sel.producto_id)
  if (!p) return
  const cant = Number(sel.cantidad) || 1
  if (esNuevo.value) {
    items.value.push({ producto_id: p.id, nombre: p.nombre, precio: p.precio, cantidad: cant })
  } else {
    const ci = await agregarItemCombo(comboId.value, p.id, cant)
    items.value.push({ id: ci.id, producto_id: p.id, nombre: p.nombre, precio: p.precio, cantidad: cant })
  }
  sel.producto_id = ''
  sel.cantidad = 1
  recalcularPrecioSiCorresponde()
}

async function quitarItem(it, idx) {
  if (!esNuevo.value && it.id) {
    await quitarItemCombo(it.id)
    // Sin productos no puede seguir publicado.
    if (items.value.length === 1 && form.disponible) {
      await actualizarCombo(comboId.value, { disponible: false })
      form.disponible = false
    }
  }
  items.value.splice(idx, 1)
  recalcularPrecioSiCorresponde()
}

async function toggleDisponible() {
  if (!form.disponible && items.value.length === 0) {
    estado.value = { ok: false, msg: 'Agregale productos antes de activarlo.' }
    return
  }
  form.disponible = !form.disponible
  if (!esNuevo.value) await actualizarCombo(comboId.value, { disponible: form.disponible })
}

async function guardar() {
  estado.value = null
  if (!form.nombre.trim()) return (estado.value = { ok: false, msg: 'Falta el nombre.' })
  if (form.precio === '' || Number(form.precio) < 0) return (estado.value = { ok: false, msg: 'Cargá un precio válido.' })
  if (items.value.length === 0) return (estado.value = { ok: false, msg: 'Agregá al menos un producto.' })

  guardando.value = true
  const payload = {
    nombre: form.nombre.trim(),
    descripcion: form.descripcion.trim() || null,
    estacion: form.estacion,
    precio: Number(form.precio),
  }
  try {
    if (esNuevo.value) {
      const nuevo = await crearCombo({ ...payload, local_id: props.local.id, orden: 0, disponible: false })
      for (const it of items.value) await agregarItemCombo(nuevo.id, it.producto_id, it.cantidad)
      estado.value = { ok: true, msg: 'Creado — activalo cuando quieras publicarlo' }
      router.replace({ name: 'admin-combo-editar', params: { slug: route.params.slug, comboId: nuevo.id } })
    } else {
      await actualizarCombo(comboId.value, payload)
      estado.value = { ok: true, msg: 'Guardado' }
      setTimeout(volver, 600)
    }
  } catch (e) {
    estado.value = { ok: false, msg: e.message }
  } finally {
    guardando.value = false
  }
}

function volver() {
  router.push({ name: 'admin-menu', params: { slug: route.params.slug } })
}
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="max-w-2xl space-y-5 pb-24">
    <div>
      <button type="button" @click="volver" class="text-sm font-medium text-slate-500 hover:text-slate-900">
        ← Volver al menú
      </button>
      <h1 class="mt-1 text-2xl font-bold text-slate-900">{{ esNuevo ? 'Nuevo combo' : 'Editar combo' }}</h1>
    </div>

    <div class="card space-y-4 p-5">
      <div>
        <label class="mb-1 block text-sm font-medium text-slate-700">Nombre</label>
        <input v-model="form.nombre" type="text" class="input" placeholder="Ej. Combo Previa" />
      </div>
      <div>
        <label class="mb-1 block text-sm font-medium text-slate-700">Descripción</label>
        <input v-model="form.descripcion" type="text" class="input" placeholder="Opcional" />
      </div>
      <div>
        <label class="mb-1 block text-sm font-medium text-slate-700">Estación</label>
        <select v-model="form.estacion" class="input w-40">
          <option value="barra">Barra</option>
          <option value="cocina">Cocina</option>
        </select>
      </div>
      <label v-if="!esNuevo" class="flex items-center justify-between">
        <span class="text-sm text-slate-700">Disponible en la carta</span>
        <button
          type="button" role="switch" :aria-checked="form.disponible"
          @click="toggleDisponible"
          :class="['relative h-5 w-9 rounded-full transition', form.disponible ? 'bg-brand-500' : 'bg-slate-300']"
        >
          <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', form.disponible ? 'left-4' : 'left-0.5']" />
        </button>
      </label>
      <p v-else class="text-xs text-slate-400">Se crea oculto. Lo activás desde acá una vez que esté listo.</p>
    </div>

    <div class="card p-5">
      <h2 class="label">Productos del combo</h2>
      <ul v-if="items.length" class="mt-2 divide-y divide-slate-100">
        <li v-for="(it, idx) in items" :key="it.id ?? idx" class="flex items-center justify-between py-2 text-sm">
          <span>{{ it.cantidad }}× {{ it.nombre }} <span class="text-slate-400">({{ pesos(it.precio) }} c/u)</span></span>
          <button type="button" @click="quitarItem(it, idx)" class="text-xs font-medium text-red-500 hover:text-red-700">Quitar</button>
        </li>
      </ul>
      <p v-else class="mt-2 text-sm text-slate-400">Todavía no elegiste productos.</p>

      <div class="mt-3 flex flex-wrap gap-2">
        <select v-model="sel.producto_id" class="input flex-1">
          <option value="" disabled>Elegí un producto…</option>
          <option v-for="p in disponiblesParaAgregar" :key="p.id" :value="p.id">{{ p.nombre }} ({{ pesos(p.precio) }})</option>
        </select>
        <input v-model.number="sel.cantidad" type="number" min="1" class="input w-16" />
        <button type="button" @click="agregarItem" class="btn btn-ghost px-3 py-2 text-xs">+ Agregar</button>
      </div>

      <div class="mt-4 flex flex-wrap items-center gap-2 border-t border-slate-100 pt-3">
        <span v-if="items.length" class="text-sm text-slate-400 line-through">{{ pesos(sugerido) }}</span>
        <input
          v-model="form.precio"
          @input="precioTocado = true"
          type="number"
          min="0"
          step="1"
          placeholder="Precio del combo"
          class="input w-40 font-semibold"
        />
        <span class="text-xs text-slate-400">precio real del combo</span>
        <button
          v-if="items.length && Number(form.precio) !== sugerido"
          type="button"
          @click="((form.precio = sugerido), (precioTocado = true))"
          class="text-xs font-medium t-brand"
        >
          usar suma
        </button>
      </div>
    </div>

    <div class="fixed bottom-0 left-0 right-0 z-10 border-t border-slate-200 bg-white/95 backdrop-blur md:left-60">
      <div class="mx-auto flex max-w-5xl items-center justify-end gap-3 px-6 py-3">
        <span v-if="estado" :class="['text-sm font-medium', estado.ok ? 'text-green-600' : 'text-red-600']">
          {{ estado.ok ? `${estado.msg} ✓` : estado.msg }}
        </span>
        <button type="button" @click="volver" class="btn btn-ghost">{{ esNuevo ? 'Cancelar' : 'Volver' }}</button>
        <button type="button" :disabled="guardando" @click="guardar" class="btn btn-dark">
          {{ guardando ? 'Guardando…' : esNuevo ? 'Crear combo' : 'Guardar cambios' }}
        </button>
      </div>
    </div>
  </section>
</template>
