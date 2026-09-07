-- Mismo bug que el de combo_id, ahora del lado de producto_id: al borrar un
-- producto ya pedido, "pedido_items.producto_id" se pone en NULL (ON DELETE
-- SET NULL, a propósito). El fix anterior solo relajó el lado "combo" del
-- check constraint; faltaba relajar también el lado "producto". Ahora el
-- constraint solo exige exclusión mutua (un ítem no puede tener los dos a
-- la vez), sin exigir que el que corresponde a su tipo esté siempre no nulo.

alter table pedido_items drop constraint pedido_items_check;

alter table pedido_items add constraint pedido_items_check
  check (
    (tipo = 'producto' and combo_id is null)
    or
    (tipo = 'combo' and producto_id is null)
  );
