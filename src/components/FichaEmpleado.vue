<script setup>
import { ref, watch } from 'vue'
import { actualizarFichaEquipo } from '../lib/admin'
import { notificarExito, notificarError } from '../lib/toast'

const props = defineProps({ local: Object, miembro: Object })
const emit = defineEmits(['cerrar', 'guardado'])

const nombre = ref('')
const telefono = ref('')
const notas = ref('')
const guardando = ref(false)

watch(
  () => props.miembro,
  (m) => {
    nombre.value = m?.nombre ?? ''
    telefono.value = m?.telefono ?? ''
    notas.value = m?.notas ?? ''
  },
  { immediate: true },
)

function ultimoAccesoTexto(m) {
  if (!m.ultimo_acceso) return 'Nunca entró'
  return new Date(m.ultimo_acceso).toLocaleString('es-AR', {
    day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit',
  })
}
function fechaAltaTexto(m) {
  return new Date(m.creado).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

async function guardar() {
  guardando.value = true
  try {
    await actualizarFichaEquipo(props.local.id, props.miembro.usuario_id, {
      nombre: nombre.value, telefono: telefono.value, notas: notas.value,
    })
    notificarExito('Ficha guardada.')
    emit('guardado')
  } catch (e) {
    notificarError(e.message)
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <div v-if="miembro" class="fixed inset-0 z-[90] flex items-center justify-center bg-slate-900/60 p-4" @click.self="emit('cerrar')">
    <div class="card w-full max-w-md p-6">
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <h2 class="text-lg font-bold text-slate-900">Ficha de empleado</h2>
          <p class="mt-0.5 truncate text-sm text-slate-500">{{ miembro.email }}</p>
        </div>
        <button type="button" @click="emit('cerrar')" class="shrink-0 text-slate-400 hover:text-slate-700" aria-label="Cerrar">
          ✕
        </button>
      </div>

      <form @submit.prevent="guardar" class="mt-4 space-y-3">
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Nombre</label>
          <input v-model="nombre" type="text" placeholder="Nombre y apellido" class="input w-full" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Teléfono</label>
          <input v-model="telefono" type="tel" placeholder="+54 9 11 1234 5678" class="input w-full" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Notas</label>
          <textarea v-model="notas" rows="3" placeholder="Ej: turno tarde, empieza en marzo…" class="input w-full"></textarea>
        </div>

        <div class="rounded-lg bg-slate-50 p-3 text-xs text-slate-500">
          <p>Alta: {{ fechaAltaTexto(miembro) }}</p>
          <p class="mt-0.5">{{ ultimoAccesoTexto(miembro) }}</p>
          <p v-if="!miembro.email_confirmado" class="mt-0.5 font-medium text-amber-700">Mail sin confirmar todavía.</p>
        </div>

        <button type="submit" :disabled="guardando" class="btn btn-dark w-full">
          {{ guardando ? 'Guardando…' : 'Guardar' }}
        </button>
      </form>
    </div>
  </div>
</template>
