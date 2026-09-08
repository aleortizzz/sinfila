<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { listarLocalesSuperadmin, activarLocal, registrarPago, suspenderLocal, cerrarSesion } from '../lib/auth'
import { pesos } from '../lib/formato'

const router = useRouter()

const cargando = ref(true)
const error = ref(null)
const locales = ref([])
const accionando = ref(null) // local_id en curso

// Inputs por local: { [local_id]: { precio, monto } }
const inputs = reactive({})

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
      if (!inputs[l.local_id]) inputs[l.local_id] = { precio: l.precio_mensual || '', monto: l.precio_mensual || '' }
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
        <p class="text-sm text-slate-500">{{ locales.length }} local(es) en la plataforma.</p>

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
                <p class="text-xs text-slate-500">
                  {{ l.negocio_nombre }} · {{ l.email_contacto }} ·
                  <RouterLink :to="`/${l.slug}`" class="underline" target="_blank">/{{ l.slug }}</RouterLink>
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
              </div>
            </div>
          </li>
          <li v-if="locales.length === 0" class="text-slate-500">Todavía no hay locales.</li>
        </ul>
      </section>
    </div>
  </div>
</template>
