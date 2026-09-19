<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import {
  listarLocalesSuperadmin,
  registrarPago,
  suspenderLocal,
  alternarCartaLocal,
  fijarFechasLocal,
  obtenerHistorialLocal,
  cerrarSesion,
} from '../lib/auth'
import { pesos } from '../lib/formato'
import { notificarExito, notificarError } from '../lib/toast'
import { ESTADOS, fecha } from '../lib/superadmin'

const route = useRoute()
const router = useRouter()

const cargando = ref(true)
const error = ref(null)
const local = ref(null)
const accionando = ref(false)

const monto = ref('')
const soloFecha = (d) => (d ? String(d).slice(0, 10) : '')
const fechas = reactive({ trial_hasta: '', proximo_vencimiento: '', gracia_hasta: '' })

async function cargar() {
  cargando.value = true
  error.value = null
  try {
    const todos = await listarLocalesSuperadmin()
    const encontrado = todos.find((l) => l.slug === route.params.slug)
    if (!encontrado) {
      error.value = 'No encontramos este local.'
      return
    }
    local.value = encontrado
    monto.value = monto.value || encontrado.precio_mensual || ''
    fechas.trial_hasta = soloFecha(encontrado.trial_hasta)
    fechas.proximo_vencimiento = soloFecha(encontrado.proximo_vencimiento)
    fechas.gracia_hasta = soloFecha(encontrado.gracia_hasta)
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

async function pago() {
  if (!(Number(monto.value) > 0)) return alert('Cargá el monto del pago.')
  if (!confirm(`¿Registrar un pago de ${pesos(monto.value)} para "${local.value.local_nombre}"?`)) return
  accionando.value = true
  try {
    await registrarPago(local.value.local_id, monto.value)
    await cargar()
    notificarExito('Pago registrado.')
  } catch (e) {
    notificarError(e.message)
  } finally {
    accionando.value = false
  }
}

async function suspender() {
  if (
    !confirm(
      `¿Suspender "${local.value.local_nombre}"? Deja de poder recibir pedidos y el dueño no puede operar el panel — pero la carta se sigue viendo, marcada como cerrada.`,
    )
  )
    return
  accionando.value = true
  try {
    await suspenderLocal(local.value.local_id)
    await cargar()
    notificarExito(`"${local.value.local_nombre}" suspendido.`)
  } catch (e) {
    notificarError(e.message)
  } finally {
    accionando.value = false
  }
}

async function alternarCarta() {
  const activar = local.value.carta_deshabilitada
  if (
    !activar &&
    !confirm(`¿Deshabilitar la carta de "${local.value.local_nombre}"? Deja de verse del todo, sin importar el estado de la suscripción.`)
  ) {
    return
  }
  accionando.value = true
  try {
    await alternarCartaLocal(local.value.local_id, !activar)
    await cargar()
    notificarExito(activar ? 'Carta habilitada.' : 'Carta deshabilitada.')
  } catch (e) {
    notificarError(e.message)
  } finally {
    accionando.value = false
  }
}

// El <input type="date"> solo tiene valor cuando completaste día, mes Y
// año — si dejás una fecha a medio escribir, v-model queda en '' sin
// avisar nada. Por eso acá se repiten las 3 fechas tal cual quedaron
// (con "—" si están vacías) en vez de un genérico "Guardado" — así se ve
// al toque si una quedó vacía sin querer.
async function guardarFechas() {
  accionando.value = true
  try {
    await fijarFechasLocal(local.value.local_id, {
      trialHasta: fechas.trial_hasta,
      proximoVencimiento: fechas.proximo_vencimiento,
      graciaHasta: fechas.gracia_hasta,
    })
    await cargar()
    notificarExito(
      `Guardado — Prueba: ${fecha(fechas.trial_hasta)} · Vence: ${fecha(fechas.proximo_vencimiento)} · Gracia: ${fecha(fechas.gracia_hasta)}`,
    )
  } catch (e) {
    notificarError(e.message)
  } finally {
    accionando.value = false
  }
}

// Historial: acá siempre visible entero (a diferencia de la lista, donde
// era un panel desplegable) — es una pantalla dedicada a un solo local.
const historial = ref('cargando')
async function cargarHistorial() {
  historial.value = 'cargando'
  try {
    historial.value = await obtenerHistorialLocal(local.value.local_id)
  } catch (e) {
    historial.value = e.message
  }
}
const TIPO_EVENTO = {
  pago: { txt: 'Pago', cls: 'bg-green-100 text-green-700' },
  activacion: { txt: 'Activación', cls: 'bg-blue-100 text-blue-700' },
  gracia: { txt: 'Entró en gracia', cls: 'bg-orange-100 text-orange-700' },
  suspension: { txt: 'Suspendido', cls: 'bg-red-100 text-red-700' },
  carta_deshabilitada: { txt: 'Carta deshabilitada', cls: 'bg-slate-200 text-slate-700' },
  carta_habilitada: { txt: 'Carta habilitada', cls: 'bg-slate-100 text-slate-600' },
}
const fechaHora = (d) =>
  new Date(d).toLocaleString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })

onMounted(async () => {
  // Espera a que "local" esté cargado (mismo onMounted de arriba puede
  // todavía no haber resuelto) — más simple pedirlo de nuevo acá que
  // encadenar promesas entre los dos onMounted.
  await cargar()
  if (local.value) cargarHistorial()
})

const textoBotonPago = computed(() => (local.value?.estado === 'suspendido' ? 'Registrar pago y reactivar' : 'Registrar pago'))

async function salir() {
  await cerrarSesion()
  router.push('/login')
}
</script>

<template>
  <div class="min-h-screen bg-slate-100">
    <header class="border-b border-slate-200 bg-white">
      <div class="mx-auto flex max-w-3xl items-center justify-between px-6 py-3">
        <RouterLink to="/superadmin" class="text-sm font-medium text-slate-500 hover:text-slate-900">← Volver</RouterLink>
        <button type="button" @click="salir" class="text-sm font-medium text-slate-500 hover:text-slate-900">
          Cerrar sesión
        </button>
      </div>
    </header>

    <div class="mx-auto max-w-3xl p-6">
      <section v-if="cargando" class="text-slate-500">Cargando…</section>
      <section v-else-if="error" class="text-red-600">{{ error }}</section>

      <section v-else>
        <div class="flex flex-wrap items-center gap-2">
          <h1 class="text-2xl font-bold text-slate-900">{{ local.local_nombre }}</h1>
          <span :class="['rounded-full px-2 py-0.5 text-xs font-semibold', ESTADOS[local.estado]?.cls]">
            {{ ESTADOS[local.estado]?.txt ?? local.estado }}
          </span>
          <span v-if="local.carta_deshabilitada" class="rounded-full bg-slate-800 px-2 py-0.5 text-xs font-semibold text-white">
            Carta deshabilitada
          </span>
        </div>
        <p class="mt-1 text-sm text-slate-500">{{ local.negocio_nombre }} · {{ local.email_contacto }}</p>
        <p class="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-sm font-medium">
          <RouterLink :to="`/${local.slug}`" target="_blank" class="text-slate-500 underline hover:text-slate-900">Ver carta ↗</RouterLink>
          <RouterLink :to="`/panel/${local.slug}/admin`" class="t-brand hover:underline">Panel</RouterLink>
          <RouterLink :to="`/panel/${local.slug}`" class="t-brand hover:underline">KDS</RouterLink>
        </p>
        <p class="mt-2 text-sm text-slate-500">
          <span v-if="local.trial_hasta">Prueba hasta {{ fecha(local.trial_hasta) }} · </span>
          <span v-if="local.proximo_vencimiento">Vence {{ fecha(local.proximo_vencimiento) }} · </span>
          <span v-if="local.gracia_hasta">Gracia hasta {{ fecha(local.gracia_hasta) }} · </span>
          Mensual {{ pesos(local.precio_mensual) }}
        </p>

        <!-- Pago y suscripción -->
        <div class="card mt-5 p-5">
          <h2 class="text-base font-bold text-slate-900">Pago y suscripción</h2>
          <div class="mt-3 flex flex-wrap items-center gap-2">
            <input v-model="monto" type="number" min="0" placeholder="Monto" class="input w-32" />
            <button type="button" :disabled="accionando" @click="pago" class="btn btn-dark px-3 py-2 text-xs">
              {{ textoBotonPago }}
            </button>
            <button
              v-if="local.estado !== 'suspendido'"
              type="button"
              :disabled="accionando"
              @click="suspender"
              class="btn border border-red-300 px-3 py-2 text-xs text-red-600 hover:bg-red-50"
            >
              Suspender
            </button>
          </div>
        </div>

        <!-- Carta pública -->
        <div class="card mt-4 p-5">
          <h2 class="text-base font-bold text-slate-900">Carta pública</h2>
          <p class="mt-1 text-sm text-slate-500">
            Independiente de la suscripción — para bajar la carta del todo cuando de verdad haga falta
            (pedido del dueño, disputa), sin tocar el estado de facturación.
          </p>
          <button type="button" :disabled="accionando" @click="alternarCarta" class="btn btn-ghost mt-3 px-3 py-2 text-xs">
            {{ local.carta_deshabilitada ? 'Habilitar carta' : 'Deshabilitar carta' }}
          </button>
        </div>

        <!-- Fechas (testing) -->
        <div class="card mt-4 p-5">
          <h2 class="text-base font-bold text-slate-900">Fechas de suscripción</h2>
          <p class="mt-1 text-xs text-slate-400">
            Para testing: mueve las fechas a mano (sin esperar un mes real). Los cambios de estado por
            vencimiento solo se aplican corriendo el chequeo diario (o el botón para forzarlo, en la lista de locales).
          </p>
          <div class="mt-3 flex flex-wrap items-end gap-3">
            <div>
              <label class="mb-1 block text-xs font-medium text-slate-600">Prueba hasta</label>
              <input v-model="fechas.trial_hasta" type="date" class="input py-1.5 text-sm" />
            </div>
            <div>
              <label class="mb-1 block text-xs font-medium text-slate-600">Vence</label>
              <input v-model="fechas.proximo_vencimiento" type="date" class="input py-1.5 text-sm" />
            </div>
            <div>
              <label class="mb-1 block text-xs font-medium text-slate-600">Gracia hasta</label>
              <input v-model="fechas.gracia_hasta" type="date" class="input py-1.5 text-sm" />
            </div>
            <button type="button" :disabled="accionando" @click="guardarFechas" class="btn btn-dark px-3 py-2 text-xs">
              Guardar fechas
            </button>
          </div>
        </div>

        <!-- Historial de movimientos -->
        <div class="card mt-4 p-5">
          <h2 class="text-base font-bold text-slate-900">Historial de movimientos</h2>
          <p v-if="historial === 'cargando'" class="mt-3 text-xs text-slate-400">Cargando…</p>
          <p v-else-if="typeof historial === 'string'" class="mt-3 text-xs text-red-600">{{ historial }}</p>
          <p v-else-if="historial.length === 0" class="mt-3 text-xs text-slate-400">Sin movimientos todavía.</p>
          <ul v-else class="mt-3 space-y-2">
            <li
              v-for="(ev, i) in historial" :key="i"
              class="flex flex-wrap items-start justify-between gap-2 rounded-lg bg-slate-50 px-3 py-2 text-xs"
            >
              <div class="min-w-0">
                <span :class="['rounded-full px-2 py-0.5 font-semibold', TIPO_EVENTO[ev.tipo]?.cls]">
                  {{ TIPO_EVENTO[ev.tipo]?.txt ?? ev.tipo }}
                </span>
                <p class="mt-1 text-slate-600">{{ ev.detalle }}</p>
              </div>
              <div class="shrink-0 text-right">
                <p class="text-slate-400">{{ fechaHora(ev.fecha) }}</p>
                <p v-if="ev.monto" class="font-semibold text-slate-900">{{ pesos(ev.monto) }}</p>
                <p v-if="ev.variacion_pct" class="font-semibold text-emerald-600">+{{ ev.variacion_pct }}% vs. el pago anterior</p>
              </div>
            </li>
          </ul>
        </div>
      </section>
    </div>
  </div>
</template>
