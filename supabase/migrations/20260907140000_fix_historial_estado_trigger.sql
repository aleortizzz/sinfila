-- Bug encontrado probando el Hito 2b: "after update OF estado" solo dispara
-- si la sentencia UPDATE menciona la columna "estado" explícitamente. Cuando
-- el pedido pasa a "listo" como efecto lateral del trigger
-- promover_estado_si_listo() (disparado por un UPDATE que solo toca
-- barra_lista/cocina_lista), el historial se lo perdía.
-- Fix: escuchar CUALQUIER update de la fila; la función ya filtra con
-- "is distinct from" así que solo inserta cuando el estado realmente cambió.

drop trigger if exists trg_pedido_estado_cambio on pedidos;

create trigger trg_pedido_estado_cambio
  after update on pedidos
  for each row execute function registrar_cambio_estado();
