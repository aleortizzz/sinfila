<script setup>
import { ref, watch } from 'vue'
import { debeCambiarPassword, cambiarMiPassword } from '../lib/auth'
import { notificarExito, notificarError } from '../lib/toast'
import PasswordInput from './PasswordInput.vue'

// Se monta en el KDS y en el panel admin — cualquiera de los dos puede ser
// la primera pantalla que ve un staff recién creado, según su nivel.
const props = defineProps({ localId: { type: String, default: null } })

const mostrar = ref(false)
const nueva = ref('')
const confirmar = ref('')
const guardando = ref(false)
const error = ref(null)

watch(
  () => props.localId,
  async (id) => {
    if (!id) return
    mostrar.value = await debeCambiarPassword(id)
  },
  { immediate: true },
)

async function guardar() {
  error.value = null
  if (nueva.value.length < 6) {
    error.value = 'La contraseña tiene que tener al menos 6 caracteres.'
    return
  }
  if (nueva.value !== confirmar.value) {
    error.value = 'Las dos contraseñas no coinciden.'
    return
  }
  guardando.value = true
  try {
    await cambiarMiPassword(nueva.value)
    mostrar.value = false
    notificarExito('Contraseña actualizada.')
  } catch (e) {
    error.value = e.message
    notificarError(e.message)
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <div v-if="mostrar" class="fixed inset-0 z-[90] flex items-center justify-center bg-slate-900/60 p-4">
    <div class="card w-full max-w-sm p-6">
      <h2 class="text-lg font-bold text-slate-900">Creá tu contraseña</h2>
      <p class="mt-1 text-sm text-slate-500">
        Entraste con una contraseña generada automáticamente. Elegí una propia para no olvidarla.
      </p>
      <form @submit.prevent="guardar" class="mt-4 space-y-3">
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Contraseña nueva</label>
          <PasswordInput v-model="nueva" placeholder="Mínimo 6 caracteres" autocomplete="new-password" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Confirmar contraseña</label>
          <PasswordInput v-model="confirmar" placeholder="Confirmá la contraseña" autocomplete="new-password" />
        </div>
        <p v-if="error" class="text-sm text-red-600">{{ error }}</p>
        <button type="submit" :disabled="guardando" class="btn btn-dark w-full">
          {{ guardando ? 'Guardando…' : 'Guardar y entrar' }}
        </button>
      </form>
    </div>
  </div>
</template>
