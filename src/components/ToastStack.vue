<script setup>
import { useRouter } from 'vue-router'
import { toasts } from '../lib/toast'

const router = useRouter()

// Colores pasteles (fondo clarito + texto oscuro del mismo tono) en vez de
// los sólidos de antes — mismo criterio que usan las badges de estado en
// el resto del panel (ej. SuperAdmin).
const ESTILOS = {
  exito: 'bg-emerald-100 text-emerald-800 border border-emerald-200',
  error: 'bg-red-100 text-red-800 border border-red-200',
  advertencia: 'bg-amber-100 text-amber-800 border border-amber-200',
  info: 'bg-blue-100 text-blue-800 border border-blue-200',
}

function click(t) {
  if (t.ruta) router.push(t.ruta)
}
</script>

<template>
  <div class="pointer-events-none fixed bottom-4 right-4 z-[100] flex flex-col gap-2">
    <TransitionGroup name="toast">
      <div
        v-for="t in toasts" :key="t.id"
        @click="click(t)"
        :class="[
          'pointer-events-auto rounded-lg px-4 py-2.5 text-sm font-medium shadow-lg',
          ESTILOS[t.tipo] || ESTILOS.exito,
          t.ruta && 'cursor-pointer hover:brightness-95',
        ]"
      >
        {{ t.mensaje }}
      </div>
    </TransitionGroup>
  </div>
</template>

<style scoped>
.toast-enter-active,
.toast-leave-active {
  transition: all 0.2s ease;
}
.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
</style>
