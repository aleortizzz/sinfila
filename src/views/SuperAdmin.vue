<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { listarLocalesSuperadmin, activarLocal, forzarChequeoVencimientos, cerrarSesion } from '../lib/auth'
import { pesos } from '../lib/formato'
import { notificarExito, notificarError } from '../lib/toast'
import { ESTADOS, fecha } from '../lib/superadmin'

const router = useRouter()

const cargando = ref(true)
const error = ref(null)
const locales = ref([])
const accionando = ref(null) // local_id en curso

// Solo hace falta guardar el precio acá (para activar) — todo lo demás
// (pago, fechas, historial, carta) se maneja en la pantalla de detalle
// de cada local.
const precios = reactive({})

async function cargar() {
  cargando.value = true
  error.value = null
  try {
    locales.value = await listarLocalesSuperadmin()
    locales.value.forEach((l) => {
      precios[l.local_id] = precios[l.local_id] ?? (l.precio_mensual || '')
    })
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

async function activar(l) {
  const precio = precios[l.local_id]
  if (!(Number(precio) > 0)) return alert('Cargá el precio mensual.')
  accionando.value = l.local_id
  try {
    await activarLocal(l.local_id, precio)
    await cargar()
    notificarExito(`"${l.local_nombre}" activado — 30 días de prueba.`)
  } catch (e) {
    notificarError(e.message)
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
    notificarExito('Chequeo de vencimientos corrido sobre todos los locales.')
  } catch (e) {
    notificarError(e.message)
  } finally {
    forzandoChequeo.value = false
  }
}

async function salir() {
  await cerrarSesion()
  router.push('/login')
}
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
          <li v-for="l in locales" :key="l.local_id" class="card flex flex-wrap items-start justify-between gap-3 p-4">
            <div class="min-w-0">
              <div class="flex items-center gap-2">
                <p class="font-bold text-slate-900">{{ l.local_nombre }}</p>
                <span :class="['rounded-full px-2 py-0.5 text-[11px] font-semibold', ESTADOS[l.estado]?.cls]">
                  {{ ESTADOS[l.estado]?.txt ?? l.estado }}
                </span>
                <span v-if="l.carta_deshabilitada" class="rounded-full bg-slate-800 px-2 py-0.5 text-[11px] font-semibold text-white">
                  Carta deshabilitada
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
                  v-model="precios[l.local_id]"
                  type="number"
                  min="0"
                  placeholder="Precio mensual"
                  class="input w-36"
                />
                <button type="button" :disabled="accionando === l.local_id" @click="activar(l)" class="btn btn-dark px-3 py-2 text-xs">
                  Activar (30 días)
                </button>
              </template>
              <RouterLink v-else :to="`/superadmin/${l.slug}`" class="btn btn-dark px-3 py-2 text-xs">
                Gestionar
              </RouterLink>
            </div>
          </li>
          <li v-if="locales.length === 0" class="text-slate-500">Todavía no hay locales.</li>
        </ul>
      </section>
    </div>
  </div>
</template>
