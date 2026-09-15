<script setup>
import { computed } from 'vue'

// Se muestra en el KDS y en el panel admin (dueño/staff, no en la carta del
// cliente) mientras el local está en "gracia" — venció el trial o la
// suscripción, pero todavía no se suspendió el servicio (ver
// actualizar_estados_vencidos() en la base). No es dismisseable a propósito:
// si se suspende, la carta pública desaparece, así que conviene que nadie se
// lo pierda.
const props = defineProps({ local: Object })

const fechaLimite = computed(() => {
  if (!props.local?.gracia_hasta) return null
  return new Date(`${props.local.gracia_hasta}T00:00:00`)
})

const diasRestantes = computed(() => {
  if (!fechaLimite.value) return null
  const hoy = new Date()
  hoy.setHours(0, 0, 0, 0)
  return Math.ceil((fechaLimite.value - hoy) / 86400000)
})

const textoDias = computed(() => {
  const d = diasRestantes.value
  if (d === null) return ''
  if (d <= 0) return 'hoy'
  if (d === 1) return 'mañana'
  return `en ${d} días`
})

const fechaTexto = computed(() => {
  if (!fechaLimite.value) return ''
  return fechaLimite.value.toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric' })
})
</script>

<template>
  <div
    v-if="local?.estado === 'gracia'"
    class="border-b-2 border-amber-300 bg-amber-50 px-4 py-2.5 text-center text-sm font-medium text-amber-800"
  >
    ⚠️ Tu suscripción venció y estás en período de gracia.
    <span v-if="fechaLimite">Tenés hasta el {{ fechaTexto }} ({{ textoDias }})</span>
    para regularizar el pago — después el servicio se suspende y la carta deja de verse.
  </div>
</template>
