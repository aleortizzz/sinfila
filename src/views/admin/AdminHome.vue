<script setup>
defineProps({ local: Object })
</script>

<template>
  <section class="max-w-3xl">
    <h1 class="text-2xl font-semibold text-slate-900">Hola{{ local ? `, ${local.nombre}` : '' }} 👋</h1>
    <p class="mt-2 text-slate-500">
      Acá van a ir las estadísticas (pedidos del día, ventas, productos top) más adelante.
    </p>
    <RouterLink
      v-if="local"
      :to="`/panel/${local.slug}/admin/menu`"
      class="mt-4 inline-block rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
    >
      Ir al menú →
    </RouterLink>
  </section>
</template>
