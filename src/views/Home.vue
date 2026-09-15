<script setup>
// Portada simple. La landing de marketing es un pendiente aparte.
//
// Si ya hay sesión activa, no tiene sentido mostrarle la landing de "Registrá
// tu local / Ya tengo cuenta" a alguien que ya está adentro — lo mandamos
// directo a lo suyo, misma lógica que ya usa Login.vue tras loguearse.
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { obtenerSesion, soySuperAdmin, miLocal } from '../lib/auth'

const router = useRouter()
const revisando = ref(true)

onMounted(async () => {
  const sesion = await obtenerSesion()
  if (sesion) {
    if (await soySuperAdmin()) return router.replace('/superadmin')
    const l = await miLocal()
    if (l?.locales?.slug) return router.replace(`/panel/${l.locales.slug}/admin`)
  }
  revisando.value = false
})
</script>

<template>
  <section v-if="revisando" class="p-20 text-center text-slate-500">Cargando…</section>

  <section v-else class="mx-auto max-w-lg px-5 py-20 text-center">
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
