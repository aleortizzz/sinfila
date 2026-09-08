import { createRouter, createWebHistory } from 'vue-router'
import { obtenerSesion } from '../lib/auth'

const routes = [
  { path: '/', name: 'home', component: () => import('../views/Home.vue') },

  { path: '/login', name: 'login', component: () => import('../views/Login.vue'), meta: { bare: true } },

  // Carta pública de un local: sinfila.tizdigital.com/<slug>
  { path: '/:slug', name: 'carta', component: () => import('../views/Carta.vue') },
  { path: '/:slug/checkout', name: 'checkout', component: () => import('../views/Checkout.vue') },
  { path: '/pedido/:id', name: 'seguimiento', component: () => import('../views/SeguimientoPedido.vue') },

  // Pantalla del local (KDS): día a día, dueño y staff.
  {
    path: '/panel/:slug',
    name: 'panel-local',
    component: () => import('../views/Local.vue'),
    meta: { requiresAuth: true, bare: true },
  },

  // Panel admin: configuración del local, menú, etc. Layout con nav propio.
  {
    path: '/panel/:slug/admin',
    component: () => import('../views/admin/AdminLayout.vue'),
    meta: { requiresAuth: true, bare: true },
    children: [
      { path: '', name: 'admin-home', component: () => import('../views/admin/AdminHome.vue') },
      { path: 'menu', name: 'admin-menu', component: () => import('../views/admin/AdminMenu.vue') },
      { path: 'promos', name: 'admin-promos', component: () => import('../views/admin/AdminPromos.vue') },
      { path: 'config', name: 'admin-config', component: () => import('../views/admin/AdminConfig.vue') },
    ],
  },
]

export const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  if (!to.meta.requiresAuth) return true
  const sesion = await obtenerSesion()
  if (!sesion) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
  return true
})
