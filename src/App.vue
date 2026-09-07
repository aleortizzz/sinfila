<script setup>
import { useRoute } from 'vue-router'

// Rutas "bare" (login, KDS, panel admin) traen su propio layout de punta a
// punta — no deben quedar atrapadas en la columna angosta pensada para la
// carta del cliente.
const route = useRoute()
</script>

<template>
  <RouterView v-if="route.meta.bare" />

  <div v-else class="min-h-screen">
    <header class="border-b border-slate-200 bg-white">
      <div class="mx-auto max-w-3xl px-4 py-3">
        <RouterLink to="/" class="font-semibold">SinFila</RouterLink>
      </div>
    </header>

    <main class="mx-auto max-w-3xl px-4 py-6">
      <RouterView />
    </main>
  </div>
</template>
