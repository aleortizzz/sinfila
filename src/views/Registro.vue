<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { obtenerSesion, registrarUsuario, registrarNegocio, miLocal } from '../lib/auth'

const router = useRouter()

const cargando = ref(true)
const yaLogueado = ref(false)
const enviando = ref(false)
const error = ref(null)
const avisoMail = ref(false)

const form = reactive({
  email: '',
  password: '',
  nombreNegocio: '',
  nombreLocal: '',
  slug: '',
  slugTocado: false,
})

// Sugerencia de URL a partir del nombre del local (mientras no lo toquen a mano).
const ACENTOS = { á: 'a', é: 'e', í: 'i', ó: 'o', ú: 'u', ñ: 'n', ü: 'u' }
const slugSugerido = computed(() =>
  form.nombreLocal
    .toLowerCase()
    .replace(/[áéíóúñü]/g, (c) => ACENTOS[c] ?? c)
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, ''),
)
function onNombreLocal() {
  if (!form.slugTocado) form.slug = slugSugerido.value
}

onMounted(async () => {
  const sesion = await obtenerSesion()
  if (sesion) {
    yaLogueado.value = true
    form.email = sesion.user.email
    // Si ya tiene un local, no tiene nada que hacer acá.
    const l = await miLocal()
    if (l?.locales?.slug) {
      router.replace(`/panel/${l.locales.slug}/admin`)
      return
    }
  }
  cargando.value = false
})

async function enviar() {
  error.value = null
  if (!form.nombreNegocio.trim() || !form.nombreLocal.trim()) {
    error.value = 'Completá el nombre del negocio y del local.'
    return
  }
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(form.slug)) {
    error.value = 'La URL solo puede tener minúsculas, números y guiones.'
    return
  }
  enviando.value = true
  try {
    if (!yaLogueado.value) {
      const { session } = await registrarUsuario(form.email.trim(), form.password)
      if (!session) {
        // El proyecto exige confirmar el mail antes de poder operar.
        avisoMail.value = true
        return
      }
    }
    const slug = await registrarNegocio(form.nombreNegocio.trim(), form.nombreLocal.trim(), form.slug)
    router.replace(`/panel/${slug}/admin`)
  } catch (e) {
    error.value = e.message
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <section class="flex min-h-screen items-center justify-center bg-slate-100 p-6">
    <div class="w-full max-w-md">
      <p class="text-center text-sm font-bold uppercase tracking-widest t-brand">SinFila</p>

      <div class="card mt-3 p-6">
        <template v-if="avisoMail">
          <h1 class="text-xl font-bold text-slate-900">Revisá tu correo</h1>
          <p class="mt-2 text-sm text-slate-500">
            Te enviamos un mail para confirmar tu cuenta. Confirmalo, iniciá sesión y volvé a
            <strong>/registro</strong> para terminar el alta de tu local.
          </p>
          <RouterLink to="/login" class="btn btn-dark mt-5 w-full">Ir a iniciar sesión</RouterLink>
        </template>

        <template v-else-if="!cargando">
          <h1 class="text-xl font-bold text-slate-900">Registrá tu local</h1>
          <p class="mt-1 text-sm text-slate-500">
            Creás la cuenta y cargás los datos. Nosotros lo activamos y arrancan los 30 días de prueba.
          </p>

          <form @submit.prevent="enviar" class="mt-6 space-y-3">
            <template v-if="!yaLogueado">
              <input v-model="form.email" type="email" placeholder="Tu email" autocomplete="email" class="input" />
              <input
                v-model="form.password"
                type="password"
                placeholder="Contraseña"
                autocomplete="new-password"
                class="input"
              />
              <div class="h-px bg-slate-100" />
            </template>

            <input v-model="form.nombreNegocio" type="text" placeholder="Nombre del negocio" class="input" />
            <input
              v-model="form.nombreLocal"
              @input="onNombreLocal"
              type="text"
              placeholder="Nombre del local"
              class="input"
            />
            <div>
              <div class="flex items-center gap-1 rounded-xl border border-slate-300 bg-white px-3.5 py-2.5 text-sm shadow-sm focus-within:border-brand-400">
                <span class="shrink-0 text-slate-400">sinfila.tizdigital.com/</span>
                <input
                  v-model="form.slug"
                  @input="form.slugTocado = true"
                  type="text"
                  placeholder="mi-local"
                  class="w-full outline-none"
                />
              </div>
              <p class="mt-1 text-xs text-slate-400">Es la dirección que va a compartir con sus clientes.</p>
            </div>

            <p v-if="error" class="text-sm text-red-600">{{ error }}</p>
            <button type="submit" :disabled="enviando" class="btn btn-dark w-full">
              {{ enviando ? 'Creando…' : 'Crear mi local' }}
            </button>
          </form>

          <p class="mt-4 text-center text-xs text-slate-400">
            ¿Ya tenés cuenta? <RouterLink to="/login" class="font-medium text-slate-600 underline">Iniciá sesión</RouterLink>
          </p>
        </template>
      </div>
    </div>
  </section>
</template>
