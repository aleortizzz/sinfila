<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter, RouterLink, RouterView } from 'vue-router'
import { obtenerLocalPorSlug } from '../../lib/locales'
import { cerrarSesion } from '../../lib/auth'

const route = useRoute()
const router = useRouter()
const local = ref(null)

onMounted(async () => {
  local.value = await obtenerLocalPorSlug(route.params.slug)
})

const NAV = [
  {
    to: (slug) => `/panel/${slug}/admin`,
    label: 'Inicio',
    exact: true,
    icon: 'M11.47 3.84a.75.75 0 011.06 0l8.25 8.25a.75.75 0 11-1.06 1.06l-.97-.97V19.5a1.5 1.5 0 01-1.5 1.5h-3a.75.75 0 01-.75-.75V15a.75.75 0 00-.75-.75h-1.5a.75.75 0 00-.75.75v5.25a.75.75 0 01-.75.75h-3a1.5 1.5 0 01-1.5-1.5V12.18l-.97.97a.75.75 0 11-1.06-1.06l8.25-8.25z',
  },
  {
    to: (slug) => `/panel/${slug}/admin/menu`,
    label: 'Menú',
    exact: false,
    icon: 'M3.75 6.75h16.5M3.75 12h16.5M3.75 17.25h16.5',
  },
  {
    to: (slug) => `/panel/${slug}/admin/promos`,
    label: 'Promos',
    exact: false,
    icon: 'M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z',
  },
  {
    to: (slug) => `/panel/${slug}`,
    label: 'Pedidos (KDS)',
    exact: false,
    icon: 'M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  },
]

const tituloPagina = computed(() => {
  if (route.name === 'admin-menu') return 'Menú'
  if (route.name === 'admin-promos') return 'Promos'
  if (route.name === 'admin-home') return 'Inicio'
  return ''
})

async function salir() {
  await cerrarSesion()
  router.push('/login')
}
</script>

<template>
  <div class="flex min-h-screen bg-slate-50">
    <aside class="flex w-60 shrink-0 flex-col bg-slate-900 px-3 py-4">
      <div class="px-2">
        <p class="text-[11px] font-semibold uppercase tracking-widest text-indigo-400">SinFila admin</p>
        <p class="mt-1 truncate text-lg font-semibold text-white">{{ local?.nombre ?? '…' }}</p>
      </div>

      <nav class="mt-6 flex flex-col gap-1">
        <RouterLink
          v-for="item in NAV"
          :key="item.label"
          :to="item.to(route.params.slug)"
          custom
          v-slot="{ href, navigate, isExactActive, isActive }"
        >
          <a
            :href="href"
            @click="navigate"
            :class="[
              'flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition',
              (item.exact ? isExactActive : isActive)
                ? 'bg-indigo-500/15 font-medium text-indigo-300'
                : 'text-slate-400 hover:bg-slate-800 hover:text-slate-100',
            ]"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" class="h-5 w-5 shrink-0">
              <path :d="item.icon" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
            {{ item.label }}
          </a>
        </RouterLink>
      </nav>

      <button
        type="button"
        @click="salir"
        class="mt-auto flex items-center gap-3 rounded-lg px-3 py-2 text-left text-sm text-slate-500 hover:bg-slate-800 hover:text-slate-200"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" class="h-5 w-5 shrink-0">
          <path
            d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15M18 12H8.25m9.75 0l-3-3m3 3l-3 3"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
        Cerrar sesión
      </button>
    </aside>

    <div class="flex-1">
      <header class="flex h-14 items-center border-b border-slate-200 bg-white px-6">
        <h1 class="text-sm font-semibold text-slate-500">{{ tituloPagina }}</h1>
      </header>

      <main class="p-6">
        <RouterView v-slot="{ Component }">
          <component :is="Component" :local="local" />
        </RouterView>
      </main>
    </div>
  </div>
</template>
