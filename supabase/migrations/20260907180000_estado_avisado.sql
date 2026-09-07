-- Nuevo estado intermedio: "listo" (la cocina/barra terminó, uso interno)
-- ya no salta directo a "entregado" al apretar el botón. Ahora pasa a
-- "avisado" (se le avisó al cliente que venga a buscarlo / en el futuro
-- dispara el push al celu del cliente) y se queda visible en pantalla —
-- con el link de WhatsApp a mano por si no aparece — hasta que alguien
-- confirma "entregado" a mano.

alter table pedidos drop constraint pedidos_estado_check;

alter table pedidos add constraint pedidos_estado_check
  check (estado in ('pendiente','en_preparacion','listo','avisado','entregado','cancelado','rechazado'));
