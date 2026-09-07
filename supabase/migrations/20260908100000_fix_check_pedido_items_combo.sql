-- Bug: al borrar un combo, "pedido_items.combo_id" se pone en NULL
-- (ON DELETE SET NULL, a propósito, para no perder el historial de
-- pedidos viejos). Pero el check constraint exigía que un ítem tipo
-- 'combo' SIEMPRE tuviera combo_id no nulo — eso choca directo con el
-- SET NULL y bloqueaba el borrado de cualquier combo ya pedido alguna vez.
-- Fix: para un ítem 'combo' alcanza con que no tenga producto_id; el
-- combo_id puede quedar en null más adelante (significa "el combo se
-- borró del catálogo, pero el pedido ya tiene su snapshot de nombre/precio").

alter table pedido_items drop constraint pedido_items_check;

alter table pedido_items add constraint pedido_items_check
  check (
    (tipo = 'producto' and producto_id is not null and combo_id is null)
    or
    (tipo = 'combo' and producto_id is null)
  );
