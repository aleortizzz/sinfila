<script setup>
import { ref, reactive, watch } from 'vue'
import {
  actualizarLocal,
  obtenerZonasAdmin,
  crearZona,
  actualizarZona,
  eliminarZona,
} from '../../lib/admin'
import { pesos } from '../../lib/formato'

const props = defineProps({ local: Object })

const cargando = ref(true)
const error = ref(null)
const guardando = ref(false)
const guardado = ref(false)
const errorGuardar = ref(null)

// Copia editable. Los `time` de Postgres llegan como "18:00:00"; el input
// type=time quiere "18:00". Vacío = null (barra/cocina heredan el general).
const form = reactive({
  nombre: '',
  horario_apertura: '',
  horario_cierre: '',
  horario_barra_apertura: '',
  horario_barra_cierre: '',
  horario_cocina_apertura: '',
  horario_cocina_cierre: '',
  logo_url: '',
  color_primario: '',
  banner_url: '',
  acepta_efectivo: true,
  acepta_transferencia: true,
  alias_transferencia: '',
  cbu_transferencia: '',
  acepta_retiro: true,
  acepta_delivery: false,
  delivery_costo_modo: 'fijo',
  delivery_costo_fijo: 0,
  delivery_minimo_compra: 0,
})

const zonas = ref([])
const nuevaZona = reactive({ barrio: '', costo: '' })

const hhmm = (t) => (t ? String(t).slice(0, 5) : '')

let cargado = false
watch(
  () => props.local,
  (l) => {
    if (!l || cargado) return
    cargado = true
    form.nombre = l.nombre ?? ''
    form.horario_apertura = hhmm(l.horario_apertura)
    form.horario_cierre = hhmm(l.horario_cierre)
    form.horario_barra_apertura = hhmm(l.horario_barra_apertura)
    form.horario_barra_cierre = hhmm(l.horario_barra_cierre)
    form.horario_cocina_apertura = hhmm(l.horario_cocina_apertura)
    form.horario_cocina_cierre = hhmm(l.horario_cocina_cierre)
    form.logo_url = l.logo_url ?? ''
    form.color_primario = l.color_primario ?? ''
    form.banner_url = l.banner_url ?? ''
    form.acepta_efectivo = l.acepta_efectivo
    form.acepta_transferencia = l.acepta_transferencia
    form.alias_transferencia = l.alias_transferencia ?? ''
    form.cbu_transferencia = l.cbu_transferencia ?? ''
    form.acepta_retiro = l.acepta_retiro
    form.acepta_delivery = l.acepta_delivery
    form.delivery_costo_modo = l.delivery_costo_modo ?? 'fijo'
    form.delivery_costo_fijo = Number(l.delivery_costo_fijo ?? 0)
    form.delivery_minimo_compra = Number(l.delivery_minimo_compra ?? 0)
    cargar()
  },
  { immediate: true },
)

async function cargar() {
  try {
    zonas.value = await obtenerZonasAdmin(props.local.id)
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

async function guardar() {
  errorGuardar.value = null
  if (!form.nombre.trim()) {
    errorGuardar.value = 'El nombre no puede quedar vacío.'
    return
  }
  guardando.value = true
  const cambios = {
    nombre: form.nombre.trim(),
    horario_apertura: form.horario_apertura || null,
    horario_cierre: form.horario_cierre || null,
    horario_barra_apertura: form.horario_barra_apertura || null,
    horario_barra_cierre: form.horario_barra_cierre || null,
    horario_cocina_apertura: form.horario_cocina_apertura || null,
    horario_cocina_cierre: form.horario_cocina_cierre || null,
    logo_url: form.logo_url.trim() || null,
    color_primario: form.color_primario.trim() || null,
    banner_url: form.banner_url.trim() || null,
    acepta_efectivo: form.acepta_efectivo,
    acepta_transferencia: form.acepta_transferencia,
    alias_transferencia: form.alias_transferencia.trim() || null,
    cbu_transferencia: form.cbu_transferencia.trim() || null,
    acepta_retiro: form.acepta_retiro,
    acepta_delivery: form.acepta_delivery,
    delivery_costo_modo: form.delivery_costo_modo,
    delivery_costo_fijo: Number(form.delivery_costo_fijo) || 0,
    delivery_minimo_compra: Number(form.delivery_minimo_compra) || 0,
  }
  try {
    await actualizarLocal(props.local.id, cambios)
    // Reflejar en el objeto que comparte el layout (sidebar) y la carta.
    Object.assign(props.local, cambios)
    guardado.value = true
    setTimeout(() => (guardado.value = false), 2500)
  } catch (e) {
    errorGuardar.value =
      e.message?.includes('permission denied')
        ? 'No tenés permiso para cambiar ese dato.'
        : e.message
  } finally {
    guardando.value = false
  }
}

// --- Zonas de delivery (CRUD inmediato, como el resto del admin) ---

async function agregarZona() {
  const barrio = nuevaZona.barrio.trim()
  if (!barrio) return
  try {
    const z = await crearZona(props.local.id, barrio, Number(nuevaZona.costo) || 0)
    zonas.value.push(z)
    zonas.value.sort((a, b) => a.barrio.localeCompare(b.barrio))
    nuevaZona.barrio = ''
    nuevaZona.costo = ''
  } catch (e) {
    alert(e.code === '23505' ? 'Ya tenés una zona con ese barrio.' : e.message)
  }
}

async function guardarZona(z) {
  try {
    await actualizarZona(z.id, { barrio: z.barrio.trim(), costo: Number(z.costo) || 0 })
  } catch (e) {
    alert(e.message)
  }
}

async function quitarZona(z) {
  if (!confirm(`¿Quitar la zona "${z.barrio}"?`)) return
  await eliminarZona(z.id)
  zonas.value = zonas.value.filter((x) => x.id !== z.id)
}
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="max-w-3xl space-y-5 pb-24">
    <div>
      <h1 class="text-2xl font-bold text-slate-900">Configuración del local</h1>
      <p class="text-sm text-slate-500">Datos, horarios, imagen, pago y delivery.</p>
    </div>

    <!-- Datos -->
    <div class="card p-5">
      <h2 class="label">Datos del local</h2>
      <div class="mt-3">
        <label class="mb-1 block text-sm font-medium text-slate-700">Nombre</label>
        <input v-model="form.nombre" type="text" class="input" placeholder="Nombre del local" />
      </div>
    </div>

    <!-- Horarios -->
    <div class="card p-5">
      <h2 class="label">Horarios</h2>
      <p class="mt-1 text-xs text-slate-400">
        Barra y cocina vacíos usan el horario general. Zona horaria: Argentina.
      </p>
      <div class="mt-3 space-y-3">
        <div
          v-for="fila in [
            ['General', 'horario_apertura', 'horario_cierre'],
            ['Barra', 'horario_barra_apertura', 'horario_barra_cierre'],
            ['Cocina', 'horario_cocina_apertura', 'horario_cocina_cierre'],
          ]"
          :key="fila[0]"
          class="flex items-center gap-3"
        >
          <span class="w-16 text-sm text-slate-600">{{ fila[0] }}</span>
          <input v-model="form[fila[1]]" type="time" class="input w-32" />
          <span class="text-slate-400">a</span>
          <input v-model="form[fila[2]]" type="time" class="input w-32" />
        </div>
      </div>
    </div>

    <!-- Branding -->
    <div class="card p-5">
      <h2 class="label">Imagen de la carta</h2>
      <p class="mt-1 text-xs text-slate-400">
        Por ahora se cargan como URL (más adelante: subir el archivo).
      </p>
      <div class="mt-3 space-y-3">
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Logo (URL)</label>
          <input v-model="form.logo_url" type="url" class="input" placeholder="https://…" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Banner / portada (URL)</label>
          <input v-model="form.banner_url" type="url" class="input" placeholder="https://…" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Color principal</label>
          <div class="flex items-center gap-3">
            <input
              :value="form.color_primario || '#f5401f'"
              @input="form.color_primario = $event.target.value"
              type="color"
              class="h-10 w-14 shrink-0 cursor-pointer rounded-lg border border-slate-300 bg-white"
            />
            <input v-model="form.color_primario" type="text" class="input" placeholder="#f5401f (vacío = color por defecto)" />
            <button
              v-if="form.color_primario"
              type="button"
              @click="form.color_primario = ''"
              class="text-xs font-medium text-slate-500 hover:text-slate-900"
            >
              Limpiar
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Pago -->
    <div class="card p-5">
      <h2 class="label">Pago</h2>
      <div class="mt-3 space-y-3">
        <label class="flex items-center justify-between">
          <span class="text-sm text-slate-700">Acepta efectivo</span>
          <button
            type="button" role="switch" :aria-checked="form.acepta_efectivo"
            @click="form.acepta_efectivo = !form.acepta_efectivo"
            :class="['relative h-5 w-9 rounded-full transition', form.acepta_efectivo ? 'bg-brand-500' : 'bg-slate-300']"
          >
            <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', form.acepta_efectivo ? 'left-4' : 'left-0.5']" />
          </button>
        </label>
        <label class="flex items-center justify-between">
          <span class="text-sm text-slate-700">Acepta transferencia</span>
          <button
            type="button" role="switch" :aria-checked="form.acepta_transferencia"
            @click="form.acepta_transferencia = !form.acepta_transferencia"
            :class="['relative h-5 w-9 rounded-full transition', form.acepta_transferencia ? 'bg-brand-500' : 'bg-slate-300']"
          >
            <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', form.acepta_transferencia ? 'left-4' : 'left-0.5']" />
          </button>
        </label>
        <div v-if="form.acepta_transferencia" class="space-y-2 border-t border-slate-100 pt-3">
          <input v-model="form.alias_transferencia" type="text" class="input" placeholder="Alias (ej. bar.de.prueba.mp)" />
          <input v-model="form.cbu_transferencia" type="text" class="input" placeholder="CBU (opcional)" />
        </div>
      </div>
    </div>

    <!-- Entrega -->
    <div class="card p-5">
      <h2 class="label">Entrega</h2>
      <div class="mt-3 space-y-3">
        <label class="flex items-center justify-between">
          <span class="text-sm text-slate-700">Retiro en el local</span>
          <button
            type="button" role="switch" :aria-checked="form.acepta_retiro"
            @click="form.acepta_retiro = !form.acepta_retiro"
            :class="['relative h-5 w-9 rounded-full transition', form.acepta_retiro ? 'bg-brand-500' : 'bg-slate-300']"
          >
            <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', form.acepta_retiro ? 'left-4' : 'left-0.5']" />
          </button>
        </label>
        <label class="flex items-center justify-between">
          <span class="text-sm text-slate-700">Delivery</span>
          <button
            type="button" role="switch" :aria-checked="form.acepta_delivery"
            @click="form.acepta_delivery = !form.acepta_delivery"
            :class="['relative h-5 w-9 rounded-full transition', form.acepta_delivery ? 'bg-brand-500' : 'bg-slate-300']"
          >
            <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', form.acepta_delivery ? 'left-4' : 'left-0.5']" />
          </button>
        </label>

        <div v-if="form.acepta_delivery" class="space-y-3 border-t border-slate-100 pt-3">
          <div class="flex gap-2">
            <button
              type="button"
              @click="form.delivery_costo_modo = 'fijo'"
              :class="['chip', form.delivery_costo_modo === 'fijo' && 'chip-active']"
            >
              Costo fijo
            </button>
            <button
              type="button"
              @click="form.delivery_costo_modo = 'por_barrio'"
              :class="['chip', form.delivery_costo_modo === 'por_barrio' && 'chip-active']"
            >
              Costo por barrio
            </button>
          </div>

          <div v-if="form.delivery_costo_modo === 'fijo'">
            <label class="mb-1 block text-sm font-medium text-slate-700">Costo de envío</label>
            <input v-model="form.delivery_costo_fijo" type="number" min="0" step="1" class="input w-40" />
          </div>

          <div>
            <label class="mb-1 block text-sm font-medium text-slate-700">Mínimo de compra para delivery</label>
            <input v-model="form.delivery_minimo_compra" type="number" min="0" step="1" class="input w-40" />
            <p class="mt-1 text-xs text-slate-400">0 = sin mínimo.</p>
          </div>

          <!-- Zonas -->
          <div class="border-t border-slate-100 pt-3">
            <p class="text-sm font-medium text-slate-700">
              Zonas / barrios
              <span class="font-normal text-slate-400">
                — {{ form.delivery_costo_modo === 'por_barrio' ? 'el costo de cada barrio se cobra según esta lista' : 'definen a dónde llega el delivery' }}
              </span>
            </p>

            <ul class="mt-2 space-y-2">
              <li v-for="z in zonas" :key="z.id" class="flex items-center gap-2">
                <input v-model="z.barrio" type="text" @blur="guardarZona(z)" class="input flex-1" />
                <span class="text-xs text-slate-400">$</span>
                <input
                  v-model="z.costo"
                  type="number"
                  min="0"
                  step="1"
                  @blur="guardarZona(z)"
                  class="input w-28"
                  :disabled="form.delivery_costo_modo === 'fijo'"
                />
                <button type="button" @click="quitarZona(z)" class="text-xs font-medium text-red-500 hover:text-red-700">
                  Quitar
                </button>
              </li>
              <li v-if="zonas.length === 0" class="text-sm text-slate-400">Todavía no hay zonas.</li>
            </ul>

            <form @submit.prevent="agregarZona" class="mt-2 flex items-center gap-2">
              <input v-model="nuevaZona.barrio" type="text" placeholder="Nuevo barrio" class="input flex-1" />
              <span class="text-xs text-slate-400">$</span>
              <input v-model="nuevaZona.costo" type="number" min="0" step="1" placeholder="Costo" class="input w-28" />
              <button type="submit" class="btn btn-ghost px-3 py-2 text-xs">+ Zona</button>
            </form>
          </div>
        </div>
      </div>
    </div>

    <!-- Guardar (barra fija) -->
    <div class="fixed bottom-0 left-0 right-0 z-10 border-t border-slate-200 bg-white/95 backdrop-blur md:left-60">
      <div class="mx-auto flex max-w-5xl items-center justify-end gap-3 px-6 py-3">
        <span v-if="errorGuardar" class="text-sm text-red-600">{{ errorGuardar }}</span>
        <span v-else-if="guardado" class="text-sm font-medium text-green-600">Guardado ✓</span>
        <button type="button" :disabled="guardando" @click="guardar" class="btn btn-dark">
          {{ guardando ? 'Guardando…' : 'Guardar cambios' }}
        </button>
      </div>
    </div>
  </section>
</template>
