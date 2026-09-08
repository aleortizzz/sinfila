<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { iniciarSesion } from '../lib/auth'

const route = useRoute()
const router = useRouter()

const email = ref('')
const password = ref('')
const error = ref(null)
const cargando = ref(false)

async function enviar() {
  error.value = null
  cargando.value = true
  try {
    await iniciarSesion(email.value.trim(), password.value)
    router.replace(route.query.redirect || '/')
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
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
          <input
            v-model="email"
            type="email"
            placeholder="Email"
            autocomplete="username"
            class="input"
          />
          <input
            v-model="password"
            type="password"
            placeholder="Contraseña"
            autocomplete="current-password"
            class="input"
          />
          <p v-if="error" class="text-sm text-red-600">{{ error }}</p>
          <button type="submit" :disabled="cargando" class="btn btn-dark w-full">
            {{ cargando ? 'Entrando…' : 'Entrar' }}
          </button>
        </form>
      </div>
    </div>
  </section>
</template>
