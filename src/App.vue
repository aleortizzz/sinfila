<script setup>
import { useRoute } from 'vue-router'

// Rutas "bare" (login, KDS, panel admin) traen su propio layout de punta a
// punta. El resto (carta, checkout, seguimiento, home) son públicas y viven
// sobre el fondo cálido; cada vista arma su propio contenedor/ancho.
const route = useRoute()
</script>

<template>
  <RouterView v-if="route.meta.bare" />

  <div v-else class="min-h-screen bg-sand-50">
    <RouterView />
  </div>
</template>
