<script setup>
import { ref, reactive, watch } from 'vue'
import { obtenerProductosAdmin } from '../../lib/admin'
import {
  obtenerPromosAdmin,
  crearPromo,
  actualizarPromo,
  eliminarPromo,
  agregarProductoPromo,
  quitarProductoPromo,
} from '../../lib/admin'

const props = defineProps({ local: Object })

const DIAS = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']

const cargando = ref(true)
const error = ref(null)
const promos = ref([])
const productos = ref([])

const mostrarForm = ref(false)
const form = reactive({
  nombre: '',
  tipo: 'nxm',
  n: 3,
  m: 2,
  precio_especial: '',
  dias_semana: [],
  hora_desde: '00:00',
  hora_hasta: '23:59',
  productoIds: [],
})

const nuevoProducto = reactive({}) // { [promoId]: productoId }

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
    const [prs, prods] = await Promise.all([
      obtenerPromosAdmin(props.local.id),
      obtenerProductosAdmin(props.local.id),
    ])
    promos.value = prs
    productos.value = prods
    prs.forEach((p) => (nuevoProducto[p.id] = ''))
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

function resetForm() {
  form.nombre = ''
  form.tipo = 'nxm'
  form.n = 3
  form.m = 2
  form.precio_especial = ''
  form.dias_semana = []
  form.hora_desde = '00:00'
  form.hora_hasta = '23:59'
  form.productoIds = []
}

function abrirForm() {
  resetForm()
  mostrarForm.value = true
}

function cancelarForm() {
  mostrarForm.value = false
}

async function guardarPromo() {
  if (!form.nombre.trim()) return alert('Falta el nombre.')
  if (form.dias_semana.length === 0) return alert('Elegí al menos un día.')
  if (form.hora_desde >= form.hora_hasta) return alert('El horario "hasta" tiene que ser después del "desde".')
  if (form.productoIds.length === 0) return alert('Elegí al menos un producto — una promo no puede estar vacía.')
  if (form.tipo === 'nxm' && (!form.n || !form.m || form.n <= form.m)) {
    return alert('En NxM, N tiene que ser mayor que M (ej. 3x2: N=3, M=2).')
  }
  if (form.tipo === 'precio_especial' && !(form.precio_especial > 0)) {
    return alert('Cargá un precio especial mayor a 0.')
  }

  const payload = {
    local_id: props.local.id,
    nombre: form.nombre.trim(),
    tipo: form.tipo,
    n: form.tipo === 'nxm' ? form.n : null,
    m: form.tipo === 'nxm' ? form.m : null,
    precio_especial: form.tipo === 'precio_especial' ? Number(form.precio_especial) : null,
    dias_semana: form.dias_semana,
    hora_desde: form.hora_desde,
    hora_hasta: form.hora_hasta,
    activa: true,
  }

  try {
    const nueva = await crearPromo(payload, form.productoIds)
    const productosElegidos = productos.value.filter((p) => form.productoIds.includes(p.id))
    promos.value.push({
      ...nueva,
      promo_productos: productosElegidos.map((p) => ({ producto_id: p.id, productos: { nombre: p.nombre } })),
    })
    nuevoProducto[nueva.id] = ''
    cancelarForm()
  } catch (e) {
    alert(e.message)
  }
}

async function toggleActiva(promo) {
  const activa = !promo.activa
  await actualizarPromo(promo.id, { activa })
  promo.activa = activa
}

async function borrarPromo(promo) {
  if (!confirm(`¿Borrar la promo "${promo.nombre}"?`)) return
  await eliminarPromo(promo.id)
  promos.value = promos.value.filter((p) => p.id !== promo.id)
}

function productosDisponiblesParaPromo(promo) {
  const yaIncluidos = new Set(promo.promo_productos.map((pp) => pp.producto_id))
  return productos.value.filter((p) => !yaIncluidos.has(p.id))
}

async function agregarProducto(promo) {
  const productoId = nuevoProducto[promo.id]
  if (!productoId) return
  await agregarProductoPromo(promo.id, productoId)
  const p = productos.value.find((x) => x.id === productoId)
  promo.promo_productos.push({ producto_id: productoId, productos: { nombre: p.nombre } })
  nuevoProducto[promo.id] = ''
}

async function quitarProducto(promo, productoId) {
  await quitarProductoPromo(promo.id, productoId)
  promo.promo_productos = promo.promo_productos.filter((pp) => pp.producto_id !== productoId)
}

function resumenTipo(promo) {
  return promo.tipo === 'nxm' ? `${promo.n}x${promo.m}` : `Precio especial: $${promo.precio_especial}`
}

function resumenDias(promo) {
  return [...promo.dias_semana].sort().map((d) => DIAS[d]).join(', ')
}
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="max-w-3xl">
    <h1 class="text-2xl font-semibold text-slate-900">Promos</h1>
    <p class="text-sm text-slate-500">3x2, happy hour por franja horaria — se aplican solas en el pedido, sin apilarse.</p>

    <button
      v-if="!mostrarForm"
      type="button"
      @click="abrirForm"
      class="mt-4 w-full rounded-lg border border-dashed border-slate-300 py-2 text-sm font-medium text-slate-500 hover:border-brand-300 hover:text-brand-600"
    >
      + Nueva promo
    </button>

    <form v-if="mostrarForm" @submit.prevent="guardarPromo" class="mt-4 space-y-3 rounded-lg bg-slate-50 p-4">
      <input v-model="form.nombre" type="text" placeholder="Nombre (ej. 3x2 en tragos de $8000)" class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm" />

      <div class="flex gap-2">
        <button
          type="button"
          @click="form.tipo = 'nxm'"
          :class="['flex-1 rounded-md border px-3 py-1.5 text-sm', form.tipo === 'nxm' ? 'border-slate-900 bg-slate-900 text-white' : 'border-slate-300 text-slate-600']"
        >
          NxM (3x2, 2x1…)
        </button>
        <button
          type="button"
          @click="form.tipo = 'precio_especial'"
          :class="['flex-1 rounded-md border px-3 py-1.5 text-sm', form.tipo === 'precio_especial' ? 'border-slate-900 bg-slate-900 text-white' : 'border-slate-300 text-slate-600']"
        >
          Precio especial (happy hour)
        </button>
      </div>

      <div v-if="form.tipo === 'nxm'" class="flex items-center gap-2">
        <span class="text-sm text-slate-500">Cada</span>
        <input v-model.number="form.n" type="number" min="2" class="w-16 rounded-md border border-slate-300 bg-white px-2 py-1.5 text-sm" />
        <span class="text-sm text-slate-500">pagás</span>
        <input v-model.number="form.m" type="number" min="1" class="w-16 rounded-md border border-slate-300 bg-white px-2 py-1.5 text-sm" />
      </div>
      <div v-else class="flex items-center gap-2">
        <span class="text-sm text-slate-500">Precio especial</span>
        <input v-model="form.precio_especial" type="number" min="0" step="1" class="w-32 rounded-md border border-slate-300 bg-white px-2 py-1.5 text-sm" />
      </div>

      <div>
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Días</p>
        <div class="mt-1 flex flex-wrap gap-2">
          <label
            v-for="(dia, idx) in DIAS"
            :key="idx"
            :class="['cursor-pointer rounded-full border px-3 py-1 text-xs', form.dias_semana.includes(idx) ? 'border-slate-900 bg-slate-900 text-white' : 'border-slate-300 text-slate-600']"
          >
            <input type="checkbox" :value="idx" v-model="form.dias_semana" class="hidden" />
            {{ dia }}
          </label>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <span class="text-sm text-slate-500">De</span>
        <input v-model="form.hora_desde" type="time" class="rounded-md border border-slate-300 bg-white px-2 py-1.5 text-sm" />
        <span class="text-sm text-slate-500">a</span>
        <input v-model="form.hora_hasta" type="time" class="rounded-md border border-slate-300 bg-white px-2 py-1.5 text-sm" />
      </div>

      <div>
        <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Productos incluidos</p>
        <div class="mt-1 max-h-40 space-y-1 overflow-y-auto rounded-md border border-slate-200 bg-white p-2">
          <label v-for="p in productos" :key="p.id" class="flex items-center gap-2 text-sm">
            <input type="checkbox" :value="p.id" v-model="form.productoIds" />
            {{ p.nombre }} <span class="text-xs text-slate-400">(${{ p.precio }})</span>
          </label>
          <p v-if="productos.length === 0" class="text-sm text-slate-400">No hay productos cargados todavía.</p>
        </div>
      </div>

      <div class="flex gap-2 pt-1">
        <button type="submit" class="rounded-md bg-slate-900 px-4 py-1.5 text-sm font-medium text-white hover:bg-slate-800">Crear promo</button>
        <button type="button" @click="cancelarForm" class="rounded-md border border-slate-300 px-4 py-1.5 text-sm text-slate-600">Cancelar</button>
      </div>
    </form>

    <div v-for="promo in promos" :key="promo.id" class="mt-4 rounded-xl border border-slate-200 bg-white p-5 shadow-sm">
      <div class="flex items-center justify-between">
        <div>
          <h3 :class="['text-base font-semibold', promo.activa ? 'text-slate-900' : 'text-slate-400 line-through']">
            {{ promo.nombre }}
          </h3>
          <p class="text-xs text-slate-500">{{ resumenTipo(promo) }} · {{ resumenDias(promo) }} · {{ promo.hora_desde.slice(0,5) }} a {{ promo.hora_hasta.slice(0,5) }}</p>
        </div>
        <div class="flex items-center gap-4">
          <button
            type="button"
            role="switch"
            :aria-checked="promo.activa"
            @click="toggleActiva(promo)"
            :class="['relative h-5 w-9 rounded-full transition', promo.activa ? 'bg-brand-500' : 'bg-slate-300']"
            title="Activa"
          >
            <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', promo.activa ? 'left-4' : 'left-0.5']" />
          </button>
          <button type="button" @click="borrarPromo(promo)" class="text-xs font-medium text-red-500 hover:text-red-700">Eliminar</button>
        </div>
      </div>

      <ul class="mt-3 divide-y divide-slate-100">
        <li v-for="pp in promo.promo_productos" :key="pp.producto_id" class="flex items-center justify-between py-1.5 text-sm">
          <span>{{ pp.productos.nombre }}</span>
          <button type="button" @click="quitarProducto(promo, pp.producto_id)" class="text-xs font-medium text-red-500 hover:text-red-700">
            Quitar
          </button>
        </li>
        <li v-if="promo.promo_productos.length === 0" class="py-1.5 text-sm text-slate-400">Sin productos — no aplica a nada.</li>
      </ul>

      <div class="mt-2 flex gap-2">
        <select v-model="nuevoProducto[promo.id]" class="flex-1 rounded-md border border-slate-300 px-2 py-1.5 text-sm">
          <option value="" disabled>Agregar producto…</option>
          <option v-for="p in productosDisponiblesParaPromo(promo)" :key="p.id" :value="p.id">{{ p.nombre }}</option>
        </select>
        <button type="button" @click="agregarProducto(promo)" class="rounded-md bg-slate-900 px-3 py-1.5 text-xs font-medium text-white hover:bg-slate-800">
          Agregar
        </button>
      </div>
    </div>

    <p v-if="promos.length === 0 && !mostrarForm" class="mt-4 text-slate-500">Todavía no hay promos.</p>
  </section>
</template>
