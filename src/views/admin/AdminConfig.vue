<script setup>
import { ref, reactive, computed, watch } from 'vue'
import {
  actualizarLocal,
  obtenerHorariosAdmin,
  actualizarHorarioDia,
  obtenerZonasAdmin,
  crearZona,
  actualizarZona,
  eliminarZona,
} from '../../lib/admin'
import { pesos } from '../../lib/formato'
import { subirImagen } from '../../lib/storage'
import ImageUpload from '../../components/ImageUpload.vue'

// Índice = dia (0 = domingo, igual que extract(dow) en Postgres).
const DIAS = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
const ORDEN_SEMANA = [1, 2, 3, 4, 5, 6, 0] // lunes primero para mostrar

const props = defineProps({ local: Object })

const cargando = ref(true)
const error = ref(null)
const guardando = ref(false)
const guardado = ref(false)
const errorGuardar = ref(null)

// Copia editable de los campos de "locales". Los horarios NO van acá: son
// tabla aparte (horarios_local) con guardado inmediato, como las zonas.
const form = reactive({
  nombre: '',
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

// Pestañas: la config es larga, se muestra de a una sección.
const SECCIONES = [
  ['general', 'General'],
  ['branding', 'Branding'],
  ['pagos', 'Pagos'],
  ['envios', 'Envíos'],
]
const seccion = ref('general')

const subiendoLogo = ref(false)
const subiendoBanner = ref(false)

async function onImagen(file, prefijo) {
  const flag = prefijo === 'logo' ? subiendoLogo : subiendoBanner
  flag.value = true
  errorGuardar.value = null
  try {
    const url = await subirImagen('locales', props.local.id, file, prefijo)
    if (prefijo === 'logo') form.logo_url = url
    else form.banner_url = url
  } catch (e) {
    errorGuardar.value = e.message
  } finally {
    flag.value = false
  }
}

const horarios = ref([]) // filas de horarios_local (7)
const horariosOrdenados = computed(() =>
  ORDEN_SEMANA.map((d) => horarios.value.find((h) => h.dia === d)).filter(Boolean),
)

const zonas = ref([])
const nuevaZona = reactive({ barrio: '', costo: '' })

// Ajuste en masa del costo de todas las zonas por porcentaje (ej. "los
// envíos subieron 10%") — evita editar barrio por barrio.
const ajustePct = ref(null)
const ajusteSigno = ref('+')
const aplicandoAjuste = ref(false)

const hhmm = (t) => (t ? String(t).slice(0, 5) : '')

let cargado = false
watch(
  () => props.local,
  (l) => {
    if (!l || cargado) return
    cargado = true
    form.nombre = l.nombre ?? ''
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
    const [hs, zs] = await Promise.all([
      obtenerHorariosAdmin(props.local.id),
      obtenerZonasAdmin(props.local.id),
    ])
    horarios.value = hs.map((h) => ({ ...h, apertura: hhmm(h.apertura), cierre: hhmm(h.cierre) }))
    zonas.value = zs
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

// Horarios: guardado inmediato por día (como las zonas).
async function toggleDiaAbierto(h) {
  h.abierto = !h.abierto
  try {
    await actualizarHorarioDia(props.local.id, h.dia, { abierto: h.abierto })
  } catch (e) {
    h.abierto = !h.abierto
    alert(e.message)
  }
}

async function guardarDia(h) {
  try {
    await actualizarHorarioDia(props.local.id, h.dia, {
      apertura: h.apertura || null,
      cierre: h.cierre || null,
    })
  } catch (e) {
    alert(e.message)
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

async function aplicarAjustePorcentaje() {
  const pct = Number(ajustePct.value)
  if (!pct || pct <= 0) return
  const factor = 1 + (ajusteSigno.value === '+' ? pct : -pct) / 100
  if (factor <= 0) {
    alert('No se puede bajar 100% o más.')
    return
  }
  const verbo = ajusteSigno.value === '+' ? 'Aumentar' : 'Bajar'
  if (!confirm(`${verbo} ${pct}% el costo de ${zonas.value.length} zona(s)?`)) return
  aplicandoAjuste.value = true
  try {
    for (const z of zonas.value) {
      const nuevo = Math.max(0, Math.round(Number(z.costo) * factor))
      await actualizarZona(z.id, { costo: nuevo })
      z.costo = nuevo
    }
    ajustePct.value = null
  } catch (e) {
    alert(e.message)
  } finally {
    aplicandoAjuste.value = false
  }
}
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="max-w-3xl space-y-5 pb-24">
    <div>
      <h1 class="text-2xl font-bold text-slate-900">Configuración del local</h1>
      <p class="text-sm text-slate-500">Elegí una sección para editarla.</p>
    </div>

    <div class="flex flex-wrap gap-2">
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

    <!-- Datos -->
    <div v-show="seccion === 'general'" class="card p-5">
      <h2 class="label">Datos del local</h2>
      <div class="mt-3">
        <label class="mb-1 block text-sm font-medium text-slate-700">Nombre</label>
        <input v-model="form.nombre" type="text" class="input" placeholder="Nombre del local" />
      </div>
    </div>

    <!-- Horarios -->
    <div v-show="seccion === 'general'" class="card p-5">
      <h2 class="label">Horarios de atención</h2>
      <p class="mt-1 text-xs text-slate-400">
        Zona horaria: Argentina. Para un horario que cruza la medianoche, poné
        el cierre antes que la apertura (ej. 20:00 a 03:00). Se guarda al toque.
      </p>
      <div class="mt-3 space-y-2">
        <div v-for="h in horariosOrdenados" :key="h.dia" class="flex flex-wrap items-center gap-3">
          <span class="w-24 text-sm text-slate-600">{{ DIAS[h.dia] }}</span>
          <button
            type="button"
            role="switch"
            :aria-checked="h.abierto"
            @click="toggleDiaAbierto(h)"
            :class="['relative h-5 w-9 shrink-0 rounded-full transition', h.abierto ? 'bg-brand-500' : 'bg-slate-300']"
          >
            <span :class="['absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition', h.abierto ? 'left-4' : 'left-0.5']" />
          </button>
          <template v-if="h.abierto">
            <input v-model="h.apertura" type="time" class="input w-32" @blur="guardarDia(h)" />
            <span class="text-slate-400">a</span>
            <input v-model="h.cierre" type="time" class="input w-32" @blur="guardarDia(h)" />
          </template>
          <span v-else class="text-sm text-slate-400">Cerrado</span>
        </div>
      </div>
    </div>

    <!-- Branding -->
    <div v-show="seccion === 'branding'" class="card p-5">
      <h2 class="label">Imagen de la carta</h2>
      <div class="mt-3 space-y-4">
        <div>
          <label class="mb-1.5 block text-sm font-medium text-slate-700">Logo</label>
          <ImageUpload
            :url="form.logo_url"
            :subiendo="subiendoLogo"
            ratio="aspect-square"
            @elegir="(f) => onImagen(f, 'logo')"
            @quitar="form.logo_url = ''"
          />
        </div>
        <div>
          <label class="mb-1.5 block text-sm font-medium text-slate-700">Banner / portada</label>
          <ImageUpload
            :url="form.banner_url"
            :subiendo="subiendoBanner"
            ratio="aspect-video"
            @elegir="(f) => onImagen(f, 'banner')"
            @quitar="form.banner_url = ''"
          />
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
    <div v-show="seccion === 'pagos'" class="card p-5">
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
    <div v-show="seccion === 'envios'" class="card p-5">
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
            <p class="text-sm font-medium text-slate-700">Zonas / barrios</p>
            <p class="text-xs text-slate-400">
              {{ form.delivery_costo_modo === 'por_barrio'
                ? 'A cada barrio se le cobra el precio que le pongas acá.'
                : 'Solo definen a dónde llega el delivery. El precio es el costo fijo de arriba, igual para todos.' }}
            </p>

            <div
              v-if="zonas.length && form.delivery_costo_modo === 'por_barrio'"
              class="mt-2 flex flex-wrap items-center gap-2 rounded-lg bg-slate-50 p-2.5 text-sm"
            >
              <span class="text-slate-600">Ajustar todas:</span>
              <div class="flex overflow-hidden rounded-md border border-slate-300">
                <button
                  type="button"
                  @click="ajusteSigno = '+'"
                  :class="['px-2.5 py-1', ajusteSigno === '+' ? 'bg-slate-900 text-white' : 'bg-white text-slate-600']"
                >
                  +
                </button>
                <button
                  type="button"
                  @click="ajusteSigno = '-'"
                  :class="['border-l border-slate-300 px-2.5 py-1', ajusteSigno === '-' ? 'bg-slate-900 text-white' : 'bg-white text-slate-600']"
                >
                  −
                </button>
              </div>
              <input v-model.number="ajustePct" type="number" min="0" step="1" placeholder="10" class="input w-20 py-1" />
              <span class="text-slate-500">%</span>
              <button
                type="button"
                :disabled="!ajustePct || aplicandoAjuste"
                @click="aplicarAjustePorcentaje"
                class="btn btn-ghost px-3 py-1 text-xs"
              >
                {{ aplicandoAjuste ? 'Aplicando…' : `Aplicar a ${zonas.length} zona(s)` }}
              </button>
            </div>

            <ul class="mt-2 space-y-2">
              <li v-for="z in zonas" :key="z.id" class="flex items-center gap-2">
                <input v-model="z.barrio" type="text" @blur="guardarZona(z)" class="input flex-1" />
                <template v-if="form.delivery_costo_modo === 'por_barrio'">
                  <span class="text-xs text-slate-400">$</span>
                  <input v-model="z.costo" type="number" min="0" step="1" @blur="guardarZona(z)" class="input w-28" />
                </template>
                <button type="button" @click="quitarZona(z)" class="text-xs font-medium text-red-500 hover:text-red-700">
                  Quitar
                </button>
              </li>
              <li v-if="zonas.length === 0" class="text-sm text-slate-400">Todavía no hay zonas.</li>
            </ul>

            <form @submit.prevent="agregarZona" class="mt-2 flex items-center gap-2">
              <input v-model="nuevaZona.barrio" type="text" placeholder="Nuevo barrio" class="input flex-1" />
              <template v-if="form.delivery_costo_modo === 'por_barrio'">
                <span class="text-xs text-slate-400">$</span>
                <input v-model="nuevaZona.costo" type="number" min="0" step="1" placeholder="Costo" class="input w-28" />
              </template>
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
