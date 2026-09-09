// Filtro de período compartido por Reportes e Historial. Un solo lugar:
// si cambia acá, cambia en todos lados.

const iso = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

const cap = (s) => s.charAt(0).toUpperCase() + s.slice(1)
const fmtMes = new Intl.DateTimeFormat('es-AR', { month: 'long', year: 'numeric' })

// Lista de opciones para el <select>: Hoy · Últimos 7 días · [12 meses] · Desde el inicio.
export function opcionesPeriodo() {
  const hoy = new Date()
  const ops = [
    { id: 'hoy', label: 'Hoy' },
    { id: '7d', label: 'Últimos 7 días' },
  ]
  for (let i = 0; i < 12; i++) {
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
  if (id === '7d') {
    return {
      desde: iso(menos(6)),
      hasta: iso(hoy),
      prevDesde: iso(menos(13)),
      prevHasta: iso(menos(7)),
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
