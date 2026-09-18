-- Fix real encontrado al probar la migración anterior: `historial_local`
-- devuelve una columna de salida llamada `monto` (returns table(...)),
-- y Postgres expone eso como una variable con ese nombre dentro de la
-- función — una referencia SIN calificar a `monto` (la columna de
-- pagos_suscripcion) dentro del cuerpo queda ambigua contra esa
-- variable. Se soluciona calificando todo con el alias de la tabla.
create or replace function historial_local(p_local_id uuid)
returns table (
  fecha timestamptz,
  tipo text,
  detalle text,
  monto numeric,
  variacion_pct numeric
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not es_super_admin() then
    raise exception 'Solo el super-admin puede ver el historial.';
  end if;

  return query
  with pagos as (
    select
      ps.created_at as fecha,
      'pago'::text as tipo,
      format('Pago de $%s (período %s a %s, %s)', ps.monto, ps.periodo_desde, ps.periodo_hasta, ps.metodo) as detalle,
      ps.monto as monto,
      case
        when lag(ps.monto) over (order by ps.created_at) > 0
             and ps.monto > lag(ps.monto) over (order by ps.created_at)
        then round((ps.monto - lag(ps.monto) over (order by ps.created_at)) / lag(ps.monto) over (order by ps.created_at) * 100, 1)
        else null
      end as variacion_pct
    from pagos_suscripcion ps
    where ps.local_id = p_local_id
  ),
  eventos as (
    select le.creado_en as fecha, le.tipo as tipo, le.detalle as detalle, null::numeric as monto, null::numeric as variacion_pct
    from locales_eventos le
    where le.local_id = p_local_id
  )
  select * from pagos
  union all
  select * from eventos
  order by fecha desc;
end;
$$;
