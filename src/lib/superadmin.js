// Compartido entre SuperAdmin.vue (lista) y SuperAdminLocal.vue (detalle
// de un local) — para no duplicar el mapa de estados ni el formateo de
// fecha en los dos archivos.

export const ESTADOS = {
  pendiente_activacion: { txt: 'Pendiente', cls: 'bg-amber-100 text-amber-700' },
  trial: { txt: 'Prueba', cls: 'bg-blue-100 text-blue-700' },
  activo: { txt: 'Activo', cls: 'bg-green-100 text-green-700' },
  gracia: { txt: 'En gracia', cls: 'bg-orange-100 text-orange-700' },
  suspendido: { txt: 'Suspendido', cls: 'bg-red-100 text-red-700' },
}

// `new Date("2026-09-15")` sin hora se interpreta como UTC medianoche —
// en un huso horario detrás de UTC (como Argentina) eso muestra el día
// anterior. Forzando una hora local (T00:00:00) se evita el corrimiento.
export const fecha = (d) => (d ? new Date(`${String(d).slice(0, 10)}T00:00:00`).toLocaleDateString('es-AR') : '—')
