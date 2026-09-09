// Filtro de período compartido por Reportes e Historial. Un solo lugar:
// si cambia acá, cambia en todos lados.

const iso = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1)
const fmtMes = new Intl.DateTimeFormat('es-AR', { month: 'long', year: 'numeric' })

// Lista de opciones para el <select>:
//   Hoy · Últimos 7 / 30 / 90 días · [meses desde que abrió el local] · Desde el inicio.
// `creadoEn` (created_at del local, string o Date) recorta la lista de meses:
// no mostramos meses en los que el local todavía no existía.
export function opcionesPeriodo(creadoEn) {
  const hoy = new Date()
  const ops = [
    { id: 'hoy', label: 'Hoy' },
    { id: '7d', label: 'Últimos 7 días' },
    { id: '30d', label: 'Últimos 30 días' },
    { id: '90d', label: 'Últimos 90 días' },
  ]

  let nMeses = 12
  if (creadoEn) {
    const c = new Date(creadoEn)
    if (!Number.isNaN(c.getTime())) {
      nMeses = (hoy.getFullYear() - c.getFullYear()) * 12 + (hoy.getMonth() - c.getMonth()) + 1
      nMeses = Math.min(Math.max(nMeses, 1), 36)
    }
  }

  for (let i = 0; i < nMeses; i++) {
    const d = new Date(hoy.getFullYear(), hoy.getMonth() - i, 1)
    ops.push({
      id: `mes:${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`,
      label: cap(fmtMes.format(d)),
    })
  }
  ops.push({ id: 'inicio', label: 'Desde el inicio' })
  return ops
}

// La opción por defecto: el mes en curso.
export function periodoPorDefecto() {
  const hoy = new Date()
  return `mes:${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, '0')}`
}

// { desde, hasta, prevDesde, prevHasta } como 'YYYY-MM-DD' (o null = "desde
// que abrió el local" / "sin comparación").
export function rangoPeriodo(id) {
  const hoy = new Date()
  const menos = (n) => {
    const d = new Date(hoy)
    d.setDate(d.getDate() - n)
    return d
  }

  if (id === 'hoy') {
    return { desde: iso(hoy), hasta: iso(hoy), prevDesde: iso(menos(1)), prevHasta: iso(menos(1)) }
  }

  // 'Nd' = últimos N días (incluye hoy). El período anterior es la ventana
  // de N días justo antes.
  const md = /^(\d+)d$/.exec(id || '')
  if (md) {
    const n = Number(md[1])
    return {
      desde: iso(menos(n - 1)),
      hasta: iso(hoy),
      prevDesde: iso(menos(2 * n - 1)),
      prevHasta: iso(menos(n)),
    }
  }

  if (id && id.startsWith('mes:')) {
    const [y, m] = id.slice(4).split('-').map(Number)
    const ini = new Date(y, m - 1, 1)
    const finMes = new Date(y, m, 0)
    const fin = finMes > hoy ? hoy : finMes
    return {
      desde: iso(ini),
      hasta: iso(fin),
      prevDesde: iso(new Date(y, m - 2, 1)),
      prevHasta: iso(new Date(y, m - 1, 0)),
    }
  }

  // inicio
  return { desde: null, hasta: iso(hoy), prevDesde: null, prevHasta: null }
}
