<script setup>
import { ref, reactive, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  obtenerProductosAdmin,
  obtenerPromoAdmin,
  crearPromo,
  actualizarPromo,
  agregarProductoPromo,
  quitarProductoPromo,
} from '../../lib/admin'
import { pesos } from '../../lib/formato'

const props = defineProps({ local: Object })
const route = useRoute()
const router = useRouter()

const DIAS = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']

const promoId = computed(() => route.params.promoId || null)
const esNueva = computed(() => !promoId.value)

const cargando = ref(true)
const error = ref(null)
const guardando = ref(false)
const estado = ref(null) // { ok: boolean, msg: string }

const productos = ref([])
const productoIdsOriginales = ref([]) // para el diff de productos al guardar

const form = reactive({
  nombre: '',
  tipo: 'nxm',
  n: 3,
  m: 2,
  precio_especial: '',
  descuento_pct: '',
  dias_semana: [],
  hora_desde: '00:00',
  hora_hasta: '23:59',
  activa: true,
  productoIds: [],
})

let cargado = false
watch(
  () => props.local,
  (l) => {
    if (!l || cargado) return
    cargado = true
    cargar()
  },
  { immediate: true },
)

async function cargar() {
  try {
    productos.value = await obtenerProductosAdmin(props.local.id)
    if (!esNueva.value) {
      const p = await obtenerPromoAdmin(promoId.value)
      form.nombre = p.nombre
      form.tipo = p.tipo
      form.n = p.n ?? 3
      form.m = p.m ?? 2
      form.precio_especial = p.precio_especial ?? ''
      form.descuento_pct = p.descuento_pct ?? ''
      form.dias_semana = [...p.dias_semana]
      form.hora_desde = String(p.hora_desde).slice(0, 5)
      form.hora_hasta = String(p.hora_hasta).slice(0, 5)
      form.activa = p.activa
      form.productoIds = p.promo_productos.map((pp) => pp.producto_id)
      productoIdsOriginales.value = [...form.productoIds]
    }
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

function validar() {
  if (!form.nombre.trim()) return 'Falta el nombre.'
  if (form.dias_semana.length === 0) return 'Elegí al menos un día.'
  if (form.hora_desde >= form.hora_hasta) return 'El horario "hasta" tiene que ser después del "desde".'
  if (form.productoIds.length === 0) return 'Elegí al menos un producto.'
  if (form.tipo === 'nxm' && !(form.n > form.m && form.m >= 1)) return 'En NxM, N tiene que ser mayor que M (ej. 3x2).'
  if (form.tipo === 'porcentaje' && !(form.descuento_pct > 0 && form.descuento_pct <= 100)) {
    return 'El descuento tiene que ir entre 1 y 100%.'
  }
  if (form.tipo === 'precio_especial' && !(form.precio_especial > 0)) return 'Cargá un precio mayor a 0.'
  return null
}

async function guardar() {
  estado.value = null
  const err = validar()
  if (err) {
    estado.value = { ok: false, msg: err }
    return
  }
  guardando.value = true
  const payload = {
    local_id: props.local.id,
    nombre: form.nombre.trim(),
    tipo: form.tipo,
    n: form.tipo === 'nxm' ? Number(form.n) : null,
    m: form.tipo === 'nxm' ? Number(form.m) : null,
    precio_especial: form.tipo === 'precio_especial' ? Number(form.precio_especial) : null,
    descuento_pct: form.tipo === 'porcentaje' ? Number(form.descuento_pct) : null,
    dias_semana: form.dias_semana,
    hora_desde: form.hora_desde,
    hora_hasta: form.hora_hasta,
    activa: form.activa,
  }
  try {
    if (esNueva.value) {
      await crearPromo(payload, form.productoIds)
    } else {
      await actualizarPromo(promoId.value, payload)
      // Reconciliar productos: agregar los nuevos, sacar los quitados.
      const orig = new Set(productoIdsOriginales.value)
      const ahora = new Set(form.productoIds)
      for (const id of form.productoIds) if (!orig.has(id)) await agregarProductoPromo(promoId.value, id)
      for (const id of productoIdsOriginales.value) if (!ahora.has(id)) await quitarProductoPromo(promoId.value, id)
    }
    estado.value = { ok: true, msg: 'Guardado' }
    setTimeout(volver, 700)
  } catch (e) {
    estado.value = { ok: false, msg: e.message }
  } finally {
    guardando.value = false
  }
}

function volver() {
  router.push({ name: 'admin-promos', params: { slug: route.params.slug } })
}
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="max-w-2xl space-y-5 pb-24">
    <div>
      <button type="button" @click="volver" class="text-sm font-medium text-slate-500 hover:text-slate-900">
        ← Volver a promos
      </button>
      <h1 class="mt-1 text-2xl font-bold text-slate-900">{{ esNueva ? 'Nueva promo' : 'Editar promo' }}</h1>
    </div>

    <div class="card flex items-center justify-between gap-4 p-4">
      <div>
        <p class="font-semibold text-slate-900">{{ form.activa ? 'Promo activa' : 'Promo pausada' }}</p>
        <p class="text-xs text-slate-500">
          {{ form.activa
            ? 'Se aplica sola en los pedidos que caen en su día y horario.'
            : 'Queda guardada pero no se aplica a ningún pedido.' }}
        </p>
      </div>
      <button
        type="button"
        role="switch"
        :aria-checked="form.activa"
        @click="form.activa = !form.activa"
        :class="['relative h-6 w-11 shrink-0 rounded-full transition', form.activa ? 'bg-brand-500' : 'bg-slate-300']"
      >
        <span
          :class="[
            'absolute top-0.5 left-0.5 h-5 w-5 rounded-full bg-white shadow transition',
            form.activa ? 'translate-x-5' : 'translate-x-0',
          ]"
        />
      </button>
    </div>

    <div class="card space-y-4 p-5">
      <div>
        <label class="mb-1 block text-sm font-medium text-slate-700">Nombre</label>
        <input v-model="form.nombre" type="text" class="input" placeholder="Ej. Happy hour en tragos" />
      </div>

      <div>
        <label class="mb-1 block text-sm font-medium text-slate-700">Tipo</label>
        <div class="grid grid-cols-3 gap-2">
          <button
            v-for="op in [['nxm', 'NxM (3x2…)'], ['porcentaje', 'Descuento %'], ['precio_especial', 'Precio fijo']]"
            :key="op[0]"
            type="button"
            @click="form.tipo = op[0]"
            :class="[
              'rounded-lg border px-2 py-2 text-xs font-medium transition',
              form.tipo === op[0] ? 'border-slate-900 bg-slate-900 text-white' : 'border-slate-300 text-slate-600',
            ]"
          >
            {{ op[1] }}
          </button>
        </div>
      </div>

      <div v-if="form.tipo === 'nxm'" class="flex flex-wrap items-center gap-2 text-sm">
        <span class="text-slate-500">Cada</span>
        <input v-model.number="form.n" type="number" min="2" class="input w-20" />
        <span class="text-slate-500">pagás</span>
        <input v-model.number="form.m" type="number" min="1" class="input w-20" />
        <span class="text-xs text-slate-400">las unidades gratis son las más baratas</span>
      </div>
      <div v-else-if="form.tipo === 'porcentaje'" class="flex flex-wrap items-center gap-2 text-sm">
        <span class="text-slate-500">Descuento</span>
        <input v-model="form.descuento_pct" type="number" min="1" max="100" step="1" class="input w-24" />
        <span class="text-slate-500">% sobre el precio de cada producto</span>
      </div>
      <div v-else class="flex flex-wrap items-center gap-2 text-sm">
        <span class="text-slate-500">Precio fijo</span>
        <input v-model="form.precio_especial" type="number" min="0" step="1" class="input w-32" />
        <span class="text-xs text-slate-400">mismo precio para todos los productos de la promo</span>
      </div>
    </div>

    <div class="card space-y-3 p-5">
      <div>
        <p class="label">Días</p>
        <div class="mt-2 flex flex-wrap gap-2">
          <label
            v-for="(dia, idx) in DIAS"
            :key="idx"
            :class="['chip', form.dias_semana.includes(idx) && 'chip-active']"
          >
            <input type="checkbox" :value="idx" v-model="form.dias_semana" class="hidden" />
            {{ dia }}
          </label>
        </div>
      </div>
      <div class="flex items-center gap-2 text-sm">
        <span class="text-slate-500">De</span>
        <input v-model="form.hora_desde" type="time" class="input w-32" />
        <span class="text-slate-500">a</span>
        <input v-model="form.hora_hasta" type="time" class="input w-32" />
      </div>
    </div>

    <div class="card p-5">
      <p class="label">Productos incluidos</p>
      <p class="mt-0.5 text-xs text-slate-400">{{ form.productoIds.length }} elegido(s)</p>
      <div class="mt-2 max-h-72 space-y-0.5 overflow-y-auto rounded-lg border border-slate-200 p-2">
        <label
          v-for="p in productos"
          :key="p.id"
          class="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm hover:bg-slate-50"
        >
          <input type="checkbox" :value="p.id" v-model="form.productoIds" class="h-4 w-4 accent-brand-500" />
          <span class="flex-1">{{ p.nombre }}</span>
          <span class="text-xs text-slate-400">{{ pesos(p.precio) }}</span>
        </label>
        <p v-if="!productos.length" class="p-2 text-sm text-slate-400">No hay productos cargados.</p>
      </div>
    </div>

    <div class="fixed bottom-0 left-0 right-0 z-10 border-t border-slate-200 bg-white/95 backdrop-blur md:left-60">
      <div class="mx-auto flex max-w-5xl items-center justify-end gap-3 px-6 py-3">
        <span v-if="estado" :class="['text-sm font-medium', estado.ok ? 'text-green-600' : 'text-red-600']">
          {{ estado.ok ? 'Guardado ✓' : estado.msg }}
        </span>
        <button type="button" @click="volver" class="btn btn-ghost">Cancelar</button>
        <button type="button" :disabled="guardando" @click="guardar" class="btn btn-dark">
          {{ guardando ? 'Guardando…' : esNueva ? 'Crear promo' : 'Guardar cambios' }}
        </button>
      </div>
    </div>
  </section>
</template>
