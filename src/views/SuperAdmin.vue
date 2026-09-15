<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import {
  listarLocalesSuperadmin,
  activarLocal,
  registrarPago,
  suspenderLocal,
  fijarFechasLocal,
  forzarChequeoVencimientos,
  cerrarSesion,
} from '../lib/auth'
import { pesos } from '../lib/formato'

const router = useRouter()

const cargando = ref(true)
const error = ref(null)
const locales = ref([])
const accionando = ref(null) // local_id en curso

// Inputs por local: { [local_id]: { precio, monto, fechas: {...} } }
const inputs = reactive({})
const fechasAbiertas = ref(new Set())
function toggleFechas(localId) {
  if (fechasAbiertas.value.has(localId)) fechasAbiertas.value.delete(localId)
  else fechasAbiertas.value.add(localId)
}

// Los date de la base vienen como "2026-10-15" (o con hora si acompaña
// timestamp) — el <input type="date"> solo entiende "YYYY-MM-DD".
const soloFecha = (d) => (d ? String(d).slice(0, 10) : '')

const ESTADOS = {
  pendiente_activacion: { txt: 'Pendiente', cls: 'bg-amber-100 text-amber-700' },
  trial: { txt: 'Prueba', cls: 'bg-blue-100 text-blue-700' },
  activo: { txt: 'Activo', cls: 'bg-green-100 text-green-700' },
  gracia: { txt: 'En gracia', cls: 'bg-orange-100 text-orange-700' },
  suspendido: { txt: 'Suspendido', cls: 'bg-red-100 text-red-700' },
}

async function cargar() {
  cargando.value = true
  error.value = null
  try {
    locales.value = await listarLocalesSuperadmin()
    locales.value.forEach((l) => {
      inputs[l.local_id] = {
        precio: inputs[l.local_id]?.precio ?? (l.precio_mensual || ''),
        monto: inputs[l.local_id]?.monto ?? (l.precio_mensual || ''),
        fechas: {
          trial_hasta: soloFecha(l.trial_hasta),
          proximo_vencimiento: soloFecha(l.proximo_vencimiento),
          gracia_hasta: soloFecha(l.gracia_hasta),
        },
      }
    })
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

async function activar(l) {
  const precio = inputs[l.local_id]?.precio
  if (!(Number(precio) > 0)) return alert('Cargá el precio mensual.')
  accionando.value = l.local_id
  try {
    await activarLocal(l.local_id, precio)
    await cargar()
  } catch (e) {
    alert(e.message)
  } finally {
    accionando.value = null
  }
}

async function pago(l) {
  const monto = inputs[l.local_id]?.monto
  if (!(Number(monto) > 0)) return alert('Cargá el monto del pago.')
  if (!confirm(`¿Registrar un pago de ${pesos(monto)} para "${l.local_nombre}"?`)) return
  accionando.value = l.local_id
  try {
    await registrarPago(l.local_id, monto)
    await cargar()
  } catch (e) {
    alert(e.message)
  } finally {
    accionando.value = null
  }
}

async function suspender(l) {
  if (!confirm(`¿Suspender "${l.local_nombre}"? La carta queda offline y el dueño no puede operar.`)) return
  accionando.value = l.local_id
  try {
    await suspenderLocal(l.local_id)
    await cargar()
  } catch (e) {
    alert(e.message)
  } finally {
    accionando.value = null
  }
}

async function guardarFechas(l) {
  const f = inputs[l.local_id].fechas
  accionando.value = l.local_id
  try {
    await fijarFechasLocal(l.local_id, {
      trialHasta: f.trial_hasta,
      proximoVencimiento: f.proximo_vencimiento,
      graciaHasta: f.gracia_hasta,
    })
    await cargar()
  } catch (e) {
    alert(e.message)
  } finally {
    accionando.value = null
  }
}

const forzandoChequeo = ref(false)
async function forzarChequeo() {
  forzandoChequeo.value = true
  try {
    await forzarChequeoVencimientos()
    await cargar()
  } catch (e) {
    alert(e.message)
  } finally {
    forzandoChequeo.value = false
  }
}

async function salir() {
  await cerrarSesion()
  router.push('/login')
}

const fecha = (d) => (d ? new Date(d).toLocaleDateString('es-AR') : '—')
</script>

<template>
  <div class="min-h-screen bg-slate-100">
    <header class="border-b border-slate-200 bg-white">
      <div class="mx-auto flex max-w-5xl items-center justify-between px-6 py-3">
        <h1 class="text-lg font-bold text-slate-900">SinFila · Super-admin</h1>
        <button type="button" @click="salir" class="text-sm font-medium text-slate-500 hover:text-slate-900">
          Cerrar sesión
        </button>
      </div>
    </header>

    <div class="mx-auto max-w-5xl p-6">
      <section v-if="cargando" class="text-slate-500">Cargando…</section>
      <section v-else-if="error" class="text-red-600">{{ error }}</section>

      <section v-else>
        <div class="flex flex-wrap items-center justify-between gap-2">
          <p class="text-sm text-slate-500">{{ locales.length }} local(es) en la plataforma.</p>
          <button type="button" :disabled="forzandoChequeo" @click="forzarChequeo" class="btn btn-ghost text-xs">
            {{ forzandoChequeo ? 'Corriendo…' : 'Forzar chequeo de vencimientos ahora' }}
          </button>
        </div>
        <p class="mt-1 text-xs text-slate-400">
          Este chequeo corre solo una vez por día (de madrugada); este botón lo corre ya mismo
          sobre TODOS los locales, para no tener que esperar al probar fechas.
        </p>

        <ul class="mt-4 space-y-3">
          <li v-for="l in locales" :key="l.local_id" class="card p-4">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="min-w-0">
                <div class="flex items-center gap-2">
                  <p class="font-bold text-slate-900">{{ l.local_nombre }}</p>
                  <span :class="['rounded-full px-2 py-0.5 text-[11px] font-semibold', ESTADOS[l.estado]?.cls]">
                    {{ ESTADOS[l.estado]?.txt ?? l.estado }}
                  </span>
                </div>
                <p class="text-xs text-slate-500">{{ l.negocio_nombre }} · {{ l.email_contacto }}</p>
                <p class="mt-1 flex flex-wrap gap-x-3 gap-y-1 text-xs font-medium">
                  <RouterLink :to="`/${l.slug}`" target="_blank" class="text-slate-500 underline hover:text-slate-900">
                    Ver carta ↗
                  </RouterLink>
                  <RouterLink :to="`/panel/${l.slug}/admin`" class="t-brand hover:underline">Panel</RouterLink>
                  <RouterLink :to="`/panel/${l.slug}`" class="t-brand hover:underline">KDS</RouterLink>
                </p>
                <p class="mt-1 text-xs text-slate-400">
                  <span v-if="l.trial_hasta">Prueba hasta {{ fecha(l.trial_hasta) }} · </span>
                  <span v-if="l.proximo_vencimiento">Vence {{ fecha(l.proximo_vencimiento) }} · </span>
                  <span v-if="l.gracia_hasta">Gracia hasta {{ fecha(l.gracia_hasta) }} · </span>
                  Mensual {{ pesos(l.precio_mensual) }}
                </p>
              </div>

              <div class="flex shrink-0 flex-wrap items-center gap-2">
                <template v-if="l.estado === 'pendiente_activacion'">
                  <input
                    v-model="inputs[l.local_id].precio"
                    type="number"
                    min="0"
                    placeholder="Precio mensual"
                    class="input w-36"
                  />
                  <button type="button" :disabled="accionando === l.local_id" @click="activar(l)" class="btn btn-dark px-3 py-2 text-xs">
                    Activar (30 días)
                  </button>
                </template>
                <template v-else>
                  <input
                    v-model="inputs[l.local_id].monto"
                    type="number"
                    min="0"
                    placeholder="Monto"
                    class="input w-32"
                  />
                  <button type="button" :disabled="accionando === l.local_id" @click="pago(l)" class="btn btn-dark px-3 py-2 text-xs">
                    {{ l.estado === 'suspendido' ? 'Registrar pago y reactivar' : 'Registrar pago' }}
                  </button>
                  <button
                    v-if="l.estado !== 'suspendido'"
                    type="button"
                    :disabled="accionando === l.local_id"
                    @click="suspender(l)"
                    class="btn border border-red-300 px-3 py-2 text-xs text-red-600 hover:bg-red-50"
                  >
                    Suspender
                  </button>
                </template>
                <button type="button" @click="toggleFechas(l.local_id)" class="btn btn-ghost px-3 py-2 text-xs">
                  {{ fechasAbiertas.has(l.local_id) ? 'Cerrar fechas' : 'Editar fechas' }}
                </button>
              </div>
            </div>

            <div v-if="fechasAbiertas.has(l.local_id)" class="mt-3 border-t border-slate-100 pt-3">
              <p class="text-xs text-slate-400">
                Para testing: mueve las fechas de suscripción a mano (sin esperar un mes real) y
                usá "Forzar chequeo de vencimientos" arriba para ver el efecto al toque.
              </p>
              <div class="mt-2 flex flex-wrap items-end gap-3">
                <div>
                  <label class="mb-1 block text-xs font-medium text-slate-600">Prueba hasta</label>
                  <input v-model="inputs[l.local_id].fechas.trial_hasta" type="date" class="input py-1.5 text-sm" />
                </div>
                <div>
                  <label class="mb-1 block text-xs font-medium text-slate-600">Vence</label>
                  <input v-model="inputs[l.local_id].fechas.proximo_vencimiento" type="date" class="input py-1.5 text-sm" />
                </div>
                <div>
                  <label class="mb-1 block text-xs font-medium text-slate-600">Gracia hasta</label>
                  <input v-model="inputs[l.local_id].fechas.gracia_hasta" type="date" class="input py-1.5 text-sm" />
                </div>
                <button
                  type="button"
                  :disabled="accionando === l.local_id"
                  @click="guardarFechas(l)"
                  class="btn btn-dark px-3 py-2 text-xs"
                >
                  Guardar fechas
                </button>
              </div>
            </div>
          </li>
          <li v-if="locales.length === 0" class="text-slate-500">Todavía no hay locales.</li>
        </ul>
      </section>
    </div>
  </div>
</template>
