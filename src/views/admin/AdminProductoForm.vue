<script setup>
import { ref, reactive, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  obtenerCategoriasAdmin,
  obtenerProductoAdmin,
  crearProducto,
  actualizarProducto,
  crearGrupoOpciones,
  actualizarGrupoOpciones,
  eliminarGrupoOpciones,
  crearOpcion,
  actualizarOpcion,
  eliminarOpcion,
} from '../../lib/admin'
import { subirImagen } from '../../lib/storage'
import ImageUpload from '../../components/ImageUpload.vue'

const props = defineProps({ local: Object })
const route = useRoute()
const router = useRouter()

const productoId = computed(() => route.params.productoId || null)
const esNuevo = computed(() => !productoId.value)

const cargando = ref(true)
const error = ref(null)
const guardando = ref(false)
const estado = ref(null) // { ok, msg }

const categorias = ref([])
const form = reactive({
  nombre: '',
  descripcion: '',
  precio: '',
  foto_url: '',
  estacion: 'barra',
  categoria_id: '',
  disponible: true,
})

// "Armado": grupos de opciones. Solo tiene sentido sobre un producto ya
// creado (necesitan su id), así que la sección aparece recién en edición.
const grupos = ref([])
const nuevoGrupo = reactive({ nombre: '', obligatorio: true })
const nuevaOpcion = reactive({}) // { [grupoId]: { nombre, precioAjuste } }

const subiendoFoto = ref(false)
async function onFoto(file) {
  subiendoFoto.value = true
  estado.value = null
  try {
    form.foto_url = await subirImagen('productos', props.local.id, file, 'foto')
  } catch (e) {
    estado.value = { ok: false, msg: e.message }
  } finally {
    subiendoFoto.value = false
  }
}

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
// Al crear un producto nuevo saltamos a su ruta de edición (para el armado).
watch(
  () => route.params.productoId,
  () => {
    if (arrancado) cargar()
  },
)

async function cargar() {
  cargando.value = true
  try {
    categorias.value = await obtenerCategoriasAdmin(props.local.id)
    if (esNuevo.value) {
      form.categoria_id = route.query.categoria || categorias.value[0]?.id || ''
    } else {
      const p = await obtenerProductoAdmin(productoId.value)
      form.nombre = p.nombre
      form.descripcion = p.descripcion ?? ''
      form.precio = p.precio
      form.foto_url = p.foto_url ?? ''
      form.estacion = p.estacion
      form.categoria_id = p.categoria_id
      form.disponible = p.disponible
      grupos.value = p.grupos_opciones
      grupos.value.forEach((g) => (nuevaOpcion[g.id] = { nombre: '', precioAjuste: 0 }))
    }
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

async function guardar() {
  estado.value = null
  if (!form.nombre.trim()) return (estado.value = { ok: false, msg: 'Falta el nombre.' })
  if (form.precio === '' || Number(form.precio) < 0) return (estado.value = { ok: false, msg: 'Cargá un precio válido.' })
  if (!form.categoria_id) return (estado.value = { ok: false, msg: 'Elegí una categoría.' })

  guardando.value = true
  const payload = {
    nombre: form.nombre.trim(),
    descripcion: form.descripcion.trim() || null,
    precio: Number(form.precio),
    foto_url: form.foto_url.trim() || null,
    estacion: form.estacion,
    categoria_id: form.categoria_id,
    disponible: form.disponible,
    local_id: props.local.id,
  }
  try {
    if (esNuevo.value) {
      const nuevo = await crearProducto(payload)
      estado.value = { ok: true, msg: 'Creado — agregale el armado si lleva' }
      // Pasar a modo edición del nuevo (habilita la sección de armado).
      router.replace({
        name: 'admin-producto-editar',
        params: { slug: route.params.slug, productoId: nuevo.id },
      })
    } else {
      await actualizarProducto(productoId.value, payload)
      estado.value = { ok: true, msg: 'Guardado' }
      setTimeout(volver, 600)
    }
  } catch (e) {
    estado.value = { ok: false, msg: e.message }
  } finally {
    guardando.value = false
  }
}

// --- Armado (guardado inmediato, como el resto del admin) ---
async function agregarGrupo() {
  if (!nuevoGrupo.nombre.trim()) return
  const g = await crearGrupoOpciones(productoId.value, nuevoGrupo.nombre.trim(), nuevoGrupo.obligatorio, grupos.value.length)
  grupos.value.push(g)
  nuevaOpcion[g.id] = { nombre: '', precioAjuste: 0 }
  nuevoGrupo.nombre = ''
  nuevoGrupo.obligatorio = true
}
async function guardarGrupo(g) {
  try {
    await actualizarGrupoOpciones(g.id, { nombre: g.nombre, obligatorio: g.obligatorio })
  } catch (e) {
    alert(e.message)
  }
}
async function borrarGrupo(g) {
  if (!confirm(`¿Borrar el grupo "${g.nombre}" y sus opciones?`)) return
  await eliminarGrupoOpciones(g.id)
  grupos.value = grupos.value.filter((x) => x.id !== g.id)
}
async function agregarOpcion(g) {
  const sel = nuevaOpcion[g.id]
  if (!sel?.nombre?.trim()) return
  const op = await crearOpcion(g.id, sel.nombre.trim(), Number(sel.precioAjuste) || 0, g.opciones.length)
  g.opciones.push(op)
  nuevaOpcion[g.id] = { nombre: '', precioAjuste: 0 }
}
async function guardarOpcion(op) {
  try {
    await actualizarOpcion(op.id, { nombre: op.nombre, precio_ajuste: Number(op.precio_ajuste) || 0 })
  } catch (e) {
    alert(e.message)
  }
}
async function toggleOpcionDisponible(op) {
  op.disponible = !op.disponible
  try {
    await actualizarOpcion(op.id, { disponible: op.disponible })
  } catch (e) {
    op.disponible = !op.disponible
    alert(e.message)
  }
}
async function borrarOpcion(g, op) {
  await eliminarOpcion(op.id)
  g.opciones = g.opciones.filter((x) => x.id !== op.id)
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
      <h1 class="mt-1 text-2xl font-bold text-slate-900">{{ esNuevo ? 'Nuevo producto' : 'Editar producto' }}</h1>
    </div>

    <div class="card space-y-4 p-5">
      <div>
        <label class="mb-1 block text-sm font-medium text-slate-700">Nombre</label>
        <input v-model="form.nombre" type="text" class="input" placeholder="Ej. Fernet con Coca" />
      </div>
      <div>
        <label class="mb-1 block text-sm font-medium text-slate-700">Descripción</label>
        <input v-model="form.descripcion" type="text" class="input" placeholder="Opcional" />
      </div>
      <div class="flex flex-wrap gap-4">
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Precio</label>
          <input v-model="form.precio" type="number" min="0" step="1" class="input w-40" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Categoría</label>
          <select v-model="form.categoria_id" class="input w-56">
            <option v-for="c in categorias" :key="c.id" :value="c.id">{{ c.nombre }}</option>
          </select>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Estación</label>
          <select v-model="form.estacion" class="input w-40">
            <option value="barra">Barra</option>
            <option value="cocina">Cocina</option>
          </select>
        </div>
      </div>
      <div>
        <label class="mb-1.5 block text-sm font-medium text-slate-700">Foto <span class="font-normal text-slate-400">(opcional)</span></label>
        <ImageUpload
          :url="form.foto_url"
          :subiendo="subiendoFoto"
          ratio="aspect-square"
          recomendado="800 × 600 px (4:3)"
          @elegir="onFoto"
          @quitar="form.foto_url = ''"
        />
      </div>
      <label class="flex items-center justify-between">
        <span class="text-sm text-slate-700">Disponible en la carta</span>
        <button
          type="button" role="switch" :aria-checked="form.disponible"
          @click="form.disponible = !form.disponible"
          :class="['relative h-5 w-9 rounded-full transition', form.disponible ? 'bg-brand-500' : 'bg-slate-300']"
        >
          <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', form.disponible ? 'left-4' : 'left-0.5']" />
        </button>
      </label>
    </div>

    <!-- Armado -->
    <div v-if="!esNuevo" class="card p-5">
      <h2 class="label">Armado (grupos de opciones)</h2>
      <p class="mt-1 text-xs text-slate-400">
        Cada grupo es una elección única (ej. "Elegí el relleno"). El +$ de cada opción puede ser 0.
        <strong>Obligatorio</strong>: el cliente tiene que elegir una; si lo destildás, puede dejar "Ninguna".
        El switch de cada opción la muestra u oculta en la carta (ej. te quedaste sin stock).
      </p>

      <div v-for="g in grupos" :key="g.id" class="mt-3 rounded-lg border border-slate-200 p-3">
        <div class="flex flex-wrap items-center gap-2">
          <input v-model="g.nombre" type="text" @blur="guardarGrupo(g)" class="input flex-1" />
          <label class="flex items-center gap-1.5 text-xs text-slate-500">
            <input type="checkbox" v-model="g.obligatorio" @change="guardarGrupo(g)" />
            Obligatorio
          </label>
          <button type="button" @click="borrarGrupo(g)" class="text-xs font-medium text-red-500 hover:text-red-700">
            Eliminar grupo
          </button>
        </div>

        <ul class="mt-2 space-y-1">
          <li v-for="op in g.opciones" :key="op.id" class="flex items-center gap-2">
            <input
              v-model="op.nombre"
              type="text"
              @blur="guardarOpcion(op)"
              :class="['input flex-1', !op.disponible && 'text-slate-400 line-through']"
            />
            <span class="text-xs text-slate-400">+$</span>
            <input v-model="op.precio_ajuste" type="number" step="1" @blur="guardarOpcion(op)" class="input w-24" />
            <button
              type="button"
              role="switch"
              :aria-checked="op.disponible"
              @click="toggleOpcionDisponible(op)"
              :class="['relative h-5 w-9 shrink-0 rounded-full transition', op.disponible ? 'bg-brand-500' : 'bg-slate-300']"
              title="Disponible"
            >
              <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', op.disponible ? 'left-4' : 'left-0.5']" />
            </button>
            <button type="button" @click="borrarOpcion(g, op)" class="text-xs text-red-500 hover:text-red-700">✕</button>
          </li>
        </ul>

        <div v-if="nuevaOpcion[g.id]" class="mt-2 flex items-center gap-2">
          <input v-model="nuevaOpcion[g.id].nombre" type="text" placeholder="Nueva opción" class="input flex-1" />
          <span class="text-xs text-slate-400">+$</span>
          <input v-model.number="nuevaOpcion[g.id].precioAjuste" type="number" step="1" class="input w-24" />
          <button type="button" @click="agregarOpcion(g)" class="btn btn-dark px-3 py-2 text-xs">+ Opción</button>
        </div>
      </div>

      <div class="mt-3 flex flex-wrap items-center gap-2">
        <input v-model="nuevoGrupo.nombre" type="text" placeholder="Nuevo grupo (ej. Elegí el relleno)" class="input flex-1" />
        <label class="flex items-center gap-1.5 text-xs text-slate-500">
          <input type="checkbox" v-model="nuevoGrupo.obligatorio" />
          Obligatorio
        </label>
        <button type="button" @click="agregarGrupo" class="btn btn-ghost px-3 py-2 text-xs">+ Grupo</button>
      </div>
    </div>

    <div class="fixed bottom-0 left-0 right-0 z-10 border-t border-slate-200 bg-white/95 backdrop-blur md:left-60">
      <div class="mx-auto flex max-w-5xl items-center justify-end gap-3 px-6 py-3">
        <span v-if="estado" :class="['text-sm font-medium', estado.ok ? 'text-green-600' : 'text-red-600']">
          {{ estado.ok ? `${estado.msg} ✓` : estado.msg }}
        </span>
        <button type="button" @click="volver" class="btn btn-ghost">{{ esNuevo ? 'Cancelar' : 'Volver' }}</button>
        <button type="button" :disabled="guardando" @click="guardar" class="btn btn-dark">
          {{ guardando ? 'Guardando…' : esNuevo ? 'Crear producto' : 'Guardar cambios' }}
        </button>
      </div>
    </div>
  </section>
</template>
