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
  nombre: '',
  slug: '',
  slugTocado: false,
  editandoSlug: false,
})

// La URL se arma sola con el nombre. El dueño la puede cambiar si quiere.
const ACENTOS = { á: 'a', é: 'e', í: 'i', ó: 'o', ú: 'u', ñ: 'n', ü: 'u' }
const slugAuto = computed(() =>
  form.nombre
    .toLowerCase()
    .replace(/[áéíóúñü]/g, (c) => ACENTOS[c] ?? c)
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, ''),
)
const slugFinal = computed(() => (form.slugTocado ? form.slug : slugAuto.value))

onMounted(async () => {
  const sesion = await obtenerSesion()
  if (sesion) {
    yaLogueado.value = true
    form.email = sesion.user.email
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
  if (!form.nombre.trim()) {
    error.value = 'Poné el nombre de tu local.'
    return
  }
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(slugFinal.value)) {
    error.value = 'La dirección solo puede tener minúsculas, números y guiones.'
    return
  }
  enviando.value = true
  try {
    if (!yaLogueado.value) {
      const { session } = await registrarUsuario(form.email.trim(), form.password)
      if (!session) {
        avisoMail.value = true
        return
      }
    }
    const slug = await registrarNegocio(form.nombre.trim(), slugFinal.value)
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
        <!-- Aviso: hay que confirmar el mail -->
        <template v-if="avisoMail">
          <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-amber-100 text-2xl">✉️</div>
          <h1 class="mt-3 text-center text-xl font-bold text-slate-900">Confirmá tu correo</h1>
          <p class="mt-2 text-center text-sm text-slate-500">
            Te enviamos un mail a <strong>{{ form.email }}</strong>. Abrí el enlace para verificar tu cuenta
            y después iniciá sesión para terminar el alta de tu local.
          </p>
          <button type="button" @click="router.push('/login')" class="btn btn-dark mt-5 w-full">
            Ir a iniciar sesión
          </button>
        </template>

        <!-- Formulario -->
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

            <div>
              <label class="mb-1 block text-sm font-medium text-slate-700">Nombre del local</label>
              <input v-model="form.nombre" type="text" placeholder="Ej. Bebidas Ortiz" class="input" />
            </div>

            <div v-if="form.nombre" class="rounded-xl bg-slate-50 p-3 text-sm">
              <p class="text-slate-500">La dirección de tu carta va a ser:</p>
              <p class="mt-0.5 break-all font-medium text-slate-800">
                sinfila.tizdigital.com/<span class="t-brand">{{ slugFinal || '…' }}</span>
              </p>
              <div v-if="!form.editandoSlug" class="mt-1">
                <button
                  type="button"
                  @click="((form.editandoSlug = true), (form.slug = slugFinal), (form.slugTocado = true))"
                  class="text-xs font-medium text-slate-500 underline"
                >
                  cambiar
                </button>
              </div>
              <input
                v-else
                v-model="form.slug"
                type="text"
                placeholder="mi-local"
                class="input mt-2"
              />
            </div>

            <p v-if="error" class="text-sm text-red-600">{{ error }}</p>
            <button type="submit" :disabled="enviando" class="btn btn-dark w-full">
              {{ enviando ? 'Creando…' : 'Crear mi local' }}
            </button>
          </form>

          <p class="mt-4 text-center text-xs text-slate-400">
            ¿Ya tenés cuenta?
            <RouterLink to="/login" class="font-medium text-slate-600 underline">Iniciá sesión</RouterLink>
          </p>
        </template>
      </div>
    </div>
  </section>
</template>
