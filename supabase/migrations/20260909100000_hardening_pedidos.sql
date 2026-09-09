-- ============================================================
-- Endurecimiento: los pedidos y sus ítems SOLO se crean a través de
-- crear_pedido() (security definer, corre como postgres/bypassrls y
-- recalcula todos los precios server-side).
--
-- La policy de INSERT anterior sobre pedido_items dejaba que cualquier
-- cliente insertara filas con el precio_unitario que quisiera; el trigger
-- de totales las sumaba tal cual. Eso permitía armar un pedido con precios
-- falsos sin pasar por crear_pedido. Se quitan esas policies: crear_pedido
-- no las necesita (bypassrls), y no hay otro camino legítimo de alta.
-- ============================================================

drop policy if exists pedidos_insert on pedidos;
drop policy if exists pedido_items_insert on pedido_items;

-- Los ítems de un pedido son inmutables una vez creados. El KDS solo
-- actualiza la tabla "pedidos" (estado, barra_lista, cocina_lista…), nunca
-- pedido_items.
drop policy if exists pedido_items_update on pedido_items;
