<script setup>
import { toasts } from '../lib/toast'

const ESTILOS = {
  exito: 'bg-emerald-600',
  error: 'bg-red-600',
  advertencia: 'bg-amber-500',
  info: 'bg-blue-600',
}
</script>

<template>
  <div class="pointer-events-none fixed bottom-4 right-4 z-[100] flex flex-col gap-2">
    <TransitionGroup name="toast">
      <div
        v-for="t in toasts" :key="t.id"
        :class="['pointer-events-auto rounded-lg px-4 py-2.5 text-sm font-medium text-white shadow-lg', ESTILOS[t.tipo] || ESTILOS.exito]"
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
