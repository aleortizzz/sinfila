<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { obtenerSesion, cambiarContrasena, cerrarSesion } from '../lib/auth'
import PasswordInput from '../components/PasswordInput.vue'

const router = useRouter()

const cargando = ref(true)
const tieneSesion = ref(false)
const p1 = ref('')
const p2 = ref('')
const guardando = ref(false)
const error = ref(null)
const listo = ref(false)

// Al abrir el enlace del mail, supabase-js procesa el token de la URL y deja
// una sesión temporal de recuperación. Puede tardar un tick.
supabase.auth.onAuthStateChange((_event, session) => {
  if (session) tieneSesion.value = true
})

onMounted(async () => {
  tieneSesion.value = !!(await obtenerSesion())
  cargando.value = false
})

async function guardar() {
  error.value = null
  if (p1.value.length < 6) {
    error.value = 'La contraseña tiene que tener al menos 6 caracteres.'
    return
  }
  if (p1.value !== p2.value) {
    error.value = 'Las contraseñas no coinciden.'
    return
  }
  guardando.value = true
  try {
    await cambiarContrasena(p1.value)
    await cerrarSesion()
    listo.value = true
  } catch (e) {
    error.value = e.message
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <section class="flex min-h-screen items-center justify-center bg-slate-100 p-6">
    <div class="w-full max-w-sm">
      <p class="text-center text-sm font-bold uppercase tracking-widest t-brand">SinFila</p>

      <div class="card mt-3 p-6">
        <template v-if="cargando">
          <p class="text-center text-sm text-slate-500">Cargando…</p>
        </template>

        <template v-else-if="listo">
          <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-green-100 text-2xl">✓</div>
          <h1 class="mt-3 text-center text-xl font-bold text-slate-900">Contraseña actualizada</h1>
          <button type="button" @click="router.push('/login')" class="btn btn-dark mt-5 w-full">Ingresar</button>
        </template>

        <template v-else-if="!tieneSesion">
          <h1 class="text-xl font-bold text-slate-900">Enlace no válido</h1>
          <p class="mt-2 text-sm text-slate-500">
            El enlace venció o ya se usó. Pedí uno nuevo.
          </p>
          <RouterLink to="/recuperar" class="btn btn-dark mt-5 w-full">Pedir otro enlace</RouterLink>
        </template>

        <template v-else>
          <h1 class="text-xl font-bold text-slate-900">Nueva contraseña</h1>
          <form @submit.prevent="guardar" class="mt-6 space-y-3">
            <PasswordInput v-model="p1" placeholder="Nueva contraseña" autocomplete="new-password" />
            <PasswordInput v-model="p2" placeholder="Repetí la contraseña" autocomplete="new-password" />
            <p v-if="error" class="text-sm text-red-600">{{ error }}</p>
            <button type="submit" :disabled="guardando" class="btn btn-dark w-full">
              {{ guardando ? 'Guardando…' : 'Guardar' }}
            </button>
          </form>
        </template>
      </div>
    </div>
  </section>
</template>
