-- Fix real encontrado probando la migración anterior: local_visible_publicamente()
-- no era security definer, así que su `select ... from locales` corría con
-- los permisos del que llama — y al usarla ahora en la propia policy de
-- SELECT de `locales` (20260918111500), esa consulta interna volvía a
-- evaluar la MISMA policy, en loop infinito ("stack depth limit exceeded").
-- Las demás funciones de este estilo (rol_en_local, es_super_admin) ya son
-- security definer justamente por esto — a esta le faltaba.
create or replace function local_visible_publicamente(p_local_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select estado in ('trial','activo','gracia','suspendido') and not carta_deshabilitada
  from locales where id = p_local_id;
$$;
