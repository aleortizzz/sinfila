<script setup>
// Portada simple. La landing de marketing es un pendiente aparte.
</script>

<template>
  <section class="mx-auto max-w-lg px-5 py-20 text-center">
    <p class="text-sm font-bold uppercase tracking-widest t-brand">SinFila</p>
    <h1 class="mt-3 text-3xl font-extrabold text-slate-900 sm:text-4xl">
      No hagas fila: escaneá, elegí y esperá tu pedido.
    </h1>
    <p class="mt-4 text-slate-500">
      Plataforma de pedidos para bares y kioscos.
    </p>

    <div class="mt-7 flex flex-wrap justify-center gap-3">
      <RouterLink to="/registro" class="btn btn-brand">Registrá tu local</RouterLink>
      <RouterLink to="/login" class="btn btn-ghost">Ya tengo cuenta</RouterLink>
    </div>

    <p class="mt-10 text-sm text-slate-400">
      Ejemplo:
      <RouterLink to="/bar-de-prueba" class="text-slate-600 underline">/bar-de-prueba</RouterLink>
    </p>
  </section>
</template>
