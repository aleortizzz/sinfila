-- ============================================================
-- Horarios de atención por día de la semana.
--
-- Antes: locales.horario_apertura/cierre (+ variantes barra/cocina) = un
-- solo rango, sin forma de decir "lunes cerrado" ni distinto por día.
-- Ahora: 7 filas por local (una por día), cada una abierta/cerrada con su
-- rango. Cruzar la medianoche = poner cierre <= apertura (ej. 20:00→03:00).
--
-- Las columnas viejas de locales quedan por ahora (no las borra esta
-- migración) pero la carta y crear_pedido pasan a usar horarios_local.
-- ============================================================

create table horarios_local (
  local_id uuid references locales(id) on delete cascade not null,
  -- 0 = domingo … 6 = sábado (igual que extract(dow from ...)).
  dia smallint not null check (dia between 0 and 6),
  abierto boolean not null default true,
  apertura time,
  cierre time,
  primary key (local_id, dia)
);

alter table horarios_local enable row level security;

create policy horarios_local_select on horarios_local for select
  using (local_visible_publicamente(local_id) or tiene_acceso_local(local_id));
create policy horarios_local_write on horarios_local for all
  using (es_dueño_local(local_id)) with check (es_dueño_local(local_id));

-- Backfill: para cada local existente, 7 días abiertos con el rango que ya
-- tuviera cargado en locales (o abierto todo el día si estaba en null).
insert into horarios_local (local_id, dia, abierto, apertura, cierre)
select l.id, d.dia, true, l.horario_apertura, l.horario_cierre
from locales l cross join generate_series(0, 6) as d(dia)
on conflict do nothing;

-- ¿El local está abierto AHORA? (hora de Argentina). Contempla el tramo de
-- hoy y la cola de ayer cuando el horario cruza la medianoche.
-- Si el local no tiene filas de horario (mal configurado / recién creado),
-- devuelve true — preferimos no bloquear las ventas por un dato faltante.
create or replace function local_abierto(p_local_id uuid)
returns boolean
language sql stable set search_path = public as $$
  with t as (
    select
      extract(dow from (now() at time zone 'America/Argentina/Buenos_Aires'))::int as dow,
      (now() at time zone 'America/Argentina/Buenos_Aires')::time as hora
  ),
  hoy as (
    select h.* from horarios_local h, t
    where h.local_id = p_local_id and h.dia = t.dow
  ),
  ayer as (
    select h.* from horarios_local h, t
    where h.local_id = p_local_id and h.dia = (t.dow + 6) % 7
  )
  select
    coalesce((
      select case
        when not hoy.abierto then false
        when hoy.apertura is null or hoy.cierre is null then true          -- abierto todo el día
        when hoy.cierre > hoy.apertura then (select hora from t) between hoy.apertura and hoy.cierre
        else (select hora from t) >= hoy.apertura                           -- cruza medianoche: tramo nocturno
      end
      from hoy
    ), true)
    or
    coalesce((
      select case
        when ayer.abierto and ayer.apertura is not null and ayer.cierre is not null
             and ayer.cierre <= ayer.apertura
          then (select hora from t) < ayer.cierre                          -- cola de ayer pasada la medianoche
        else false
      end
      from ayer
    ), false);
$$;

grant execute on function local_abierto(uuid) to anon, authenticated;

-- Bloqueo server-side: no se puede crear un pedido con el local cerrado.
-- Trigger sobre pedidos (no dentro de crear_pedido) así cubre cualquier
-- camino de inserción, no solo el RPC.
create or replace function _pedido_local_abierto()
returns trigger language plpgsql set search_path = public as $$
begin
  if not local_abierto(new.local_id) then
    raise exception 'El local está cerrado en este momento';
  end if;
  return new;
end;
$$;

create trigger pedido_local_abierto
  before insert on pedidos
  for each row execute function _pedido_local_abierto();
