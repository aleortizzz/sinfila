<script setup>
defineProps({ local: Object })

// Placeholders hasta el hito de estadísticas — todavía no hay datos reales.
const stats = [
  { label: 'Pedidos hoy', valor: '—', nota: 'Pronto' },
  { label: 'Ventas hoy', valor: '—', nota: 'Pronto' },
  { label: 'Ticket promedio', valor: '—', nota: 'Pronto' },
  { label: 'Productos activos', valor: '—', nota: 'Pronto' },
]
</script>

<template>
  <section>
    <h1 class="text-2xl font-bold text-slate-900">Hola{{ local ? `, ${local.nombre}` : '' }} 👋</h1>
    <p class="mt-1 text-sm text-slate-500">
      Resumen de tu local. Las métricas se activan en el próximo hito.
    </p>

    <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div v-for="s in stats" :key="s.label" class="card p-4">
        <p class="label">{{ s.label }}</p>
        <p class="mt-2 text-2xl font-extrabold text-slate-900">{{ s.valor }}</p>
        <p class="mt-1 text-xs text-slate-400">{{ s.nota }}</p>
      </div>
    </div>

    <h2 class="mt-8 text-sm font-semibold text-slate-500">Accesos rápidos</h2>
    <div v-if="local" class="mt-3 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <RouterLink
        :to="`/panel/${local.slug}/admin/menu`"
        class="card p-5 transition hover:border-brand-300 hover:shadow-md"
      >
        <p class="text-base font-semibold text-slate-900">Menú</p>
        <p class="mt-1 text-sm text-slate-500">Categorías, productos y combos de tu carta.</p>
        <span class="mt-3 inline-block text-sm font-medium t-brand">Abrir →</span>
      </RouterLink>

      <RouterLink
        :to="`/panel/${local.slug}/admin/promos`"
        class="card p-5 transition hover:border-brand-300 hover:shadow-md"
      >
        <p class="text-base font-semibold text-slate-900">Promos</p>
        <p class="mt-1 text-sm text-slate-500">3x2, happy hour y precios especiales por franja.</p>
        <span class="mt-3 inline-block text-sm font-medium t-brand">Abrir →</span>
      </RouterLink>

      <RouterLink
        :to="`/panel/${local.slug}`"
        class="card p-5 transition hover:border-brand-300 hover:shadow-md"
      >
        <p class="text-base font-semibold text-slate-900">Pedidos (KDS)</p>
        <p class="mt-1 text-sm text-slate-500">La pantalla en vivo para la barra y la cocina.</p>
        <span class="mt-3 inline-block text-sm font-medium t-brand">Abrir →</span>
      </RouterLink>

      <div class="card p-5 opacity-60">
        <p class="text-base font-semibold text-slate-900">Configuración del local</p>
        <p class="mt-1 text-sm text-slate-500">Horarios, branding, pago y delivery.</p>
        <span class="mt-3 inline-block text-sm font-medium text-slate-400">Próximo hito</span>
      </div>
    </div>
  </section>
</template>
