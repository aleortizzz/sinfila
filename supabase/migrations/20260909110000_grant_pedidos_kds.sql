-- ============================================================
-- Endurecimiento: un dueño/staff solo puede tocar el ciclo del pedido
-- desde el KDS — el estado y el "listo" de cada estación. Nunca los
-- montos, el método de pago ni los datos del cliente: eso lo fija
-- crear_pedido() (security definer) y no se edita después.
--
-- Antes, la RLS dejaba a cualquier usuario con acceso al local hacer
-- UPDATE de cualquier columna de "pedidos" (total incluido). Ahora Postgres
-- lo corta a nivel de privilegio de columna, antes de la RLS.
-- Los triggers y crear_pedido corren como postgres (bypassrls) y no se ven
-- afectados por este grant.
-- ============================================================

revoke update on pedidos from authenticated;
grant update (estado, barra_lista, cocina_lista) on pedidos to authenticated;
