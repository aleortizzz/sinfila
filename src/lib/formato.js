// Formato de moneda para la UI. Los precios llegan de Postgres como number o
// como string (numeric por PostgREST) — Number() normaliza las dos formas.
const fmt = new Intl.NumberFormat('es-AR')

export function pesos(valor) {
  return `$${fmt.format(Math.round(Number(valor) || 0))}`
}
