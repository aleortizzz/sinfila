<script setup>
import { ref } from 'vue'
import { pedirResetContrasena } from '../lib/auth'

const email = ref('')
const enviando = ref(false)
const error = ref(null)
const enviado = ref(false)

async function enviar() {
  error.value = null
  if (!email.value.trim()) {
    error.value = 'Poné tu email.'
    return
  }
  enviando.value = true
  try {
    await pedirResetContrasena(email.value)
    enviado.value = true
  } catch (e) {
    error.value = e.message
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <section class="flex min-h-screen items-center justify-center bg-slate-100 p-6">
    <div class="w-full max-w-sm">
      <p class="text-center text-sm font-bold uppercase tracking-widest t-brand">SinFila</p>

      <div class="card mt-3 p-6">
        <template v-if="enviado">
          <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-amber-100 text-amber-600">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" class="h-6 w-6">
              <path
                d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </div>
          <h1 class="mt-3 text-center text-xl font-bold text-slate-900">Revisá tu correo</h1>
          <p class="mt-2 text-center text-sm text-slate-500">
            Si <strong>{{ email }}</strong> tiene una cuenta, te llega un enlace para cambiar la contraseña.
          </p>
          <RouterLink to="/login" class="btn btn-dark mt-5 w-full">Volver a ingresar</RouterLink>
        </template>

        <template v-else>
          <h1 class="text-xl font-bold text-slate-900">Recuperar contraseña</h1>
          <p class="mt-1 text-sm text-slate-500">Te enviamos un enlace para elegir una nueva.</p>

          <form @submit.prevent="enviar" class="mt-6 space-y-3">
            <input v-model="email" type="email" placeholder="Tu email" autocomplete="email" class="input" />
            <p v-if="error" class="text-sm text-red-600">{{ error }}</p>
            <button type="submit" :disabled="enviando" class="btn btn-dark w-full">
              {{ enviando ? 'Enviando…' : 'Enviar enlace' }}
            </button>
          </form>

          <p class="mt-4 text-center text-xs text-slate-400">
            <RouterLink to="/login" class="font-medium text-slate-600 underline">Volver a ingresar</RouterLink>
          </p>
        </template>
      </div>
    </div>
  </section>
</template>
