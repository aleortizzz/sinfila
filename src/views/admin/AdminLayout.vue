<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter, RouterLink, RouterView } from 'vue-router'
import { obtenerLocalPorSlug } from '../../lib/locales'
import { cerrarSesion, soySuperAdmin } from '../../lib/auth'

const route = useRoute()
const router = useRouter()
const local = ref(null)
const cargado = ref(false)
const esSuper = ref(false)

onMounted(async () => {
  const [l, s] = await Promise.all([obtenerLocalPorSlug(route.params.slug), soySuperAdmin()])
  local.value = l
  esSuper.value = s
  cargado.value = true
})

// Estados que bloquean el panel: pendiente de activación o suspendido.
const bloqueo = computed(() => {
  if (!local.value) return null
  if (local.value.estado === 'pendiente_activacion') {
    return {
      titulo: 'Tu local está esperando activación',
      texto: 'Ya recibimos tu registro. Te avisamos apenas lo activemos y arrancan los 30 días de prueba.',
    }
  }
  if (local.value.estado === 'suspendido') {
    return {
      titulo: 'Servicio suspendido',
      texto: 'La suscripción venció. Poneté en contacto para reanudar el servicio y volver a publicar tu carta.',
    }
  }
  return null
})

const NAV = [
  {
    to: (slug) => `/panel/${slug}/admin`,
    label: 'Inicio',
    exact: true,
    icon: 'M11.47 3.84a.75.75 0 011.06 0l8.25 8.25a.75.75 0 11-1.06 1.06l-.97-.97V19.5a1.5 1.5 0 01-1.5 1.5h-3a.75.75 0 01-.75-.75V15a.75.75 0 00-.75-.75h-1.5a.75.75 0 00-.75.75v5.25a.75.75 0 01-.75.75h-3a1.5 1.5 0 01-1.5-1.5V12.18l-.97.97a.75.75 0 11-1.06-1.06l8.25-8.25z',
  },
  {
    to: (slug) => `/panel/${slug}/admin/reportes`,
    label: 'Reportes',
    exact: false,
    icon: 'M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z',
  },
  {
    to: (slug) => `/panel/${slug}/admin/historial`,
    label: 'Historial',
    exact: false,
    icon: 'M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z',
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
    to: (slug) => `/panel/${slug}/admin/config`,
    label: 'Configuración',
    exact: false,
    icon: 'M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z M15 12a3 3 0 11-6 0 3 3 0 016 0z',
  },
  {
    to: (slug) => `/panel/${slug}`,
    label: 'Pedidos (KDS)',
    exact: false,
    icon: 'M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  },
]

const tituloPagina = computed(() => {
  if (route.name === 'admin-reportes') return 'Reportes'
  if (route.name === 'admin-historial') return 'Historial'
  if (route.name === 'admin-menu') return 'Menú'
  if (route.name === 'admin-producto-nuevo') return 'Nuevo producto'
  if (route.name === 'admin-producto-editar') return 'Editar producto'
  if (route.name === 'admin-combo-nuevo') return 'Nuevo combo'
  if (route.name === 'admin-combo-editar') return 'Editar combo'
  if (route.name === 'admin-promos') return 'Promos'
  if (route.name === 'admin-promo-nueva') return 'Nueva promo'
  if (route.name === 'admin-promo-editar') return 'Editar promo'
  if (route.name === 'admin-config') return 'Configuración'
  if (route.name === 'admin-home') return 'Inicio'
  return ''
})

async function salir() {
  await cerrarSesion()
  router.push('/login')
}
</script>

<template>
  <!-- Local pendiente de activación o suspendido: pantalla de bloqueo. -->
  <div v-if="bloqueo" class="flex min-h-screen items-center justify-center bg-slate-100 p-6">
    <div class="card max-w-md p-8 text-center">
      <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-amber-100 text-2xl">⏳</div>
      <h1 class="mt-3 text-xl font-bold text-slate-900">{{ bloqueo.titulo }}</h1>
      <p class="mt-2 text-sm text-slate-500">{{ bloqueo.texto }}</p>
      <div class="mt-5 flex justify-center gap-2">
        <RouterLink v-if="esSuper" to="/superadmin" class="btn btn-dark">Ir a super-admin</RouterLink>
        <button type="button" @click="salir" class="btn btn-ghost">Cerrar sesión</button>
      </div>
    </div>
  </div>

  <div v-else-if="cargado && !local" class="flex min-h-screen items-center justify-center bg-slate-100 p-6 text-slate-500">
    No encontramos este local.
  </div>

  <div v-else class="flex min-h-screen bg-slate-50 text-slate-900">
    <aside class="sticky top-0 flex h-screen w-60 shrink-0 flex-col self-start overflow-y-auto bg-slate-900 px-3 py-5">
      <div class="flex items-center gap-2.5 px-2">
        <div class="flex h-9 w-9 items-center justify-center rounded-xl bg-brand-500 text-sm font-extrabold text-white">
          S
        </div>
        <div class="min-w-0">
          <p class="text-[10px] font-semibold uppercase tracking-widest text-slate-400">SinFila</p>
          <p class="truncate text-sm font-semibold text-white">{{ local?.nombre ?? '…' }}</p>
        </div>
      </div>

      <nav class="mt-7 flex flex-col gap-1">
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
                ? 'bg-white/10 font-medium text-white'
                : 'text-slate-400 hover:bg-white/5 hover:text-slate-100',
            ]"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" class="h-5 w-5 shrink-0">
              <path :d="item.icon" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
            {{ item.label }}
          </a>
        </RouterLink>
      </nav>

      <div class="mt-auto flex flex-col gap-1">
        <RouterLink
          v-if="esSuper"
          to="/superadmin"
          class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm text-slate-400 hover:bg-white/5 hover:text-slate-100"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" class="h-5 w-5 shrink-0">
            <path d="M12 3l7.5 3v5.25c0 4.5-3 7.5-7.5 9-4.5-1.5-7.5-4.5-7.5-9V6L12 3z" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
          Super-admin
        </RouterLink>

        <a
          :href="`/${route.params.slug}`"
          target="_blank"
          rel="noopener"
          class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm text-slate-400 hover:bg-white/5 hover:text-slate-100"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" class="h-5 w-5 shrink-0">
            <path
              d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-7.5 3L21 3m0 0h-5.25M21 3v5.25"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
          Ver carta
        </a>

        <button
          type="button"
          @click="salir"
          class="flex items-center gap-3 rounded-lg px-3 py-2 text-left text-sm text-slate-500 hover:bg-white/5 hover:text-slate-200"
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
      </div>
    </aside>

    <div class="flex-1">
      <header class="flex h-14 items-center border-b border-slate-200 bg-white px-6">
        <h1 class="text-sm font-semibold text-slate-500">{{ tituloPagina }}</h1>
      </header>

      <main class="p-6">
        <div class="mx-auto max-w-5xl">
          <RouterView v-slot="{ Component }">
            <component :is="Component" :local="local" />
          </RouterView>
        </div>
      </main>
    </div>
  </div>
</template>
