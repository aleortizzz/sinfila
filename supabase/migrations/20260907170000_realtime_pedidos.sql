-- Hito 5: sin esto, Supabase Realtime no manda ningún evento de esta tabla
-- aunque el cliente se suscriba — hay que agregarla a la publicación.
-- La seguridad de "quién recibe qué evento" la sigue resolviendo la misma
-- RLS de siempre (tiene_acceso_local): esto solo habilita el mecanismo.
alter publication supabase_realtime add table pedidos;
