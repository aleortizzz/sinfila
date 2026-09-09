<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { iniciarSesion, soySuperAdmin, miLocal, reenviarVerificacion } from '../lib/auth'
import PasswordInput from '../components/PasswordInput.vue'

const route = useRoute()
const router = useRouter()

const email = ref('')
const password = ref('')
const error = ref(null)
const cargando = ref(false)
const mailSinVerificar = ref(false) // muestra el aviso + botón de reenviar
const reenviado = ref(false)

async function enviar() {
  error.value = null
  mailSinVerificar.value = false
  cargando.value = true
  try {
    await iniciarSesion(email.value.trim(), password.value)
    if (route.query.redirect) {
      router.replace(route.query.redirect)
      return
    }
    // Sin destino explícito: mandamos a cada uno a lo suyo.
    if (await soySuperAdmin()) return router.replace('/superadmin')
    const l = await miLocal()
    router.replace(l?.locales?.slug ? `/panel/${l.locales.slug}/admin` : '/registro')
  } catch (e) {
    if (e.code === 'email_no_verificado') mailSinVerificar.value = true
    else error.value = e.message
  } finally {
    cargando.value = false
  }
}

async function reenviar() {
  try {
    await reenviarVerificacion(email.value.trim())
    reenviado.value = true
  } catch (e) {
    error.value = e.message
  }
}
</script>

<template>
  <section class="flex min-h-screen items-center justify-center bg-slate-100 p-6">
    <div class="w-full max-w-sm">
      <p class="text-center text-sm font-bold uppercase tracking-widest t-brand">SinFila</p>

      <div class="card mt-3 p-6">
        <h1 class="text-xl font-bold text-slate-900">Ingresar</h1>
        <p class="mt-1 text-sm text-slate-500">Acceso para dueños y staff del local.</p>

        <form @submit.prevent="enviar" class="mt-6 space-y-3">
          <input v-model="email" type="email" placeholder="Email" autocomplete="username" class="input" />
          <PasswordInput v-model="password" placeholder="Contraseña" autocomplete="current-password" />

          <div v-if="mailSinVerificar" class="rounded-xl bg-amber-50 p-3 text-sm text-amber-900">
            <p class="font-semibold">Todavía no verificaste tu mail</p>
            <p class="mt-0.5">Revisá tu casilla (y el spam) y confirmá el enlace que te enviamos.</p>
            <button
              v-if="!reenviado"
              type="button"
              @click="reenviar"
              class="mt-2 text-xs font-semibold text-amber-900 underline"
            >
              Reenviar el correo
            </button>
            <p v-else class="mt-2 text-xs font-medium">Te lo reenviamos ✓</p>
          </div>

          <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

          <button type="submit" :disabled="cargando" class="btn btn-dark w-full">
            {{ cargando ? 'Entrando…' : 'Entrar' }}
          </button>
        </form>

        <p class="mt-4 text-center text-xs text-slate-400">
          ¿No tenés cuenta?
          <RouterLink to="/registro" class="font-medium text-slate-600 underline">Registrá tu local</RouterLink>
        </p>
      </div>
    </div>
  </section>
</template>
