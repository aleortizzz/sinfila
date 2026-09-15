import { createRouter, createWebHistory } from 'vue-router'
import { obtenerSesion, soySuperAdmin, soyDueñoDelLocal, puedoVerFacturacion, puedoEditarMenu } from '../lib/auth'
import { obtenerLocalPorSlug } from '../lib/locales'

const routes = [
  { path: '/', name: 'home', component: () => import('../views/Home.vue') },

  { path: '/login', name: 'login', component: () => import('../views/Login.vue'), meta: { bare: true } },
  { path: '/registro', name: 'registro', component: () => import('../views/Registro.vue'), meta: { bare: true } },
  { path: '/recuperar', name: 'recuperar', component: () => import('../views/Recuperar.vue'), meta: { bare: true } },
  { path: '/nueva-contrasena', name: 'nueva-contrasena', component: () => import('../views/NuevaContrasena.vue'), meta: { bare: true } },
  {
    path: '/superadmin',
    name: 'superadmin',
    component: () => import('../views/SuperAdmin.vue'),
    meta: { bare: true, requiresAuth: true, requiresSuper: true },
  },

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
  // Todo lo de acá adentro ya está bloqueado del lado del servidor
  // (RLS/RPC exigen es_dueño_local / puede_ver_facturacion / puede_editar_menu
  // según la pantalla) — `permiso` por ruta solo evita que alguien sin ese
  // permiso vea el sidebar y pantallas rotas antes de que el backend lo frene.
  // 'dueño' = solo el dueño. 'facturacion'/'menu' = dueño o quien tenga
  // ese interruptor prendido en Equipo (ver PROGRESO.md, 2026-09-14).
  {
    path: '/panel/:slug/admin',
    component: () => import('../views/admin/AdminLayout.vue'),
    meta: { requiresAuth: true, bare: true },
    children: [
      { path: '', name: 'admin-home', component: () => import('../views/admin/AdminHome.vue'), meta: { permiso: 'facturacion' } },
      { path: 'reportes', name: 'admin-reportes', component: () => import('../views/admin/AdminReportes.vue'), meta: { permiso: 'facturacion' } },
      { path: 'historial', name: 'admin-historial', component: () => import('../views/admin/AdminHistorial.vue'), meta: { permiso: 'facturacion' } },
      { path: 'menu', name: 'admin-menu', component: () => import('../views/admin/AdminMenu.vue'), meta: { permiso: 'menu' } },
      { path: 'menu/productos/nuevo', name: 'admin-producto-nuevo', component: () => import('../views/admin/AdminProductoForm.vue'), meta: { permiso: 'menu' } },
      { path: 'menu/productos/:productoId/editar', name: 'admin-producto-editar', component: () => import('../views/admin/AdminProductoForm.vue'), meta: { permiso: 'menu' } },
      { path: 'menu/combos/nuevo', name: 'admin-combo-nuevo', component: () => import('../views/admin/AdminComboForm.vue'), meta: { permiso: 'menu' } },
      { path: 'menu/combos/:comboId/editar', name: 'admin-combo-editar', component: () => import('../views/admin/AdminComboForm.vue'), meta: { permiso: 'menu' } },
      { path: 'promos', name: 'admin-promos', component: () => import('../views/admin/AdminPromos.vue'), meta: { permiso: 'menu' } },
      { path: 'promos/nueva', name: 'admin-promo-nueva', component: () => import('../views/admin/AdminPromoForm.vue'), meta: { permiso: 'menu' } },
      { path: 'promos/:promoId/editar', name: 'admin-promo-editar', component: () => import('../views/admin/AdminPromoForm.vue'), meta: { permiso: 'menu' } },
      { path: 'config', name: 'admin-config', component: () => import('../views/admin/AdminConfig.vue'), meta: { permiso: 'dueño' } },
      { path: 'equipo', name: 'admin-equipo', component: () => import('../views/admin/AdminEquipo.vue'), meta: { permiso: 'dueño' } },
    ],
  },
]

export const router = createRouter({
  history: createWebHistory(),
  routes,
})

// El check de permiso se cachea por usuario+slug+permiso: sin esto, cada
// click dentro del propio /admin (la navegación de todos los días)
// dispararía un round-trip extra antes de cada pantalla.
// OJO: la clave tiene que incluir el usuario, no solo el slug — si no,
// loguearse con una cuenta distinta en la misma pestaña (sin recargar)
// arrastra la respuesta cacheada de la cuenta anterior para ese local.
const cachePermiso = new Map()
const CHEQUEOS = {
  dueño: soyDueñoDelLocal,
  facturacion: puedoVerFacturacion,
  menu: puedoEditarMenu,
}

async function tienePermiso(usuarioId, slug, permiso) {
  const clave = `${usuarioId}:${slug}:${permiso}`
  if (!cachePermiso.has(clave)) {
    const local = await obtenerLocalPorSlug(slug)
    cachePermiso.set(clave, !!local && (await CHEQUEOS[permiso](local.id)))
  }
  return cachePermiso.get(clave)
}

router.beforeEach(async (to) => {
  if (!to.meta.requiresAuth) return true
  const sesion = await obtenerSesion()
  if (!sesion) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
  if (to.meta.requiresSuper && !(await soySuperAdmin())) {
    return { path: '/' }
  }
  if (to.meta.permiso && !(await tienePermiso(sesion.user.id, to.params.slug, to.meta.permiso))) {
    return { path: `/panel/${to.params.slug}` }
  }
  return true
})
