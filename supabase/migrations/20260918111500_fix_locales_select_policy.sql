-- Fix de la migración anterior (20260918110000): se actualizó
-- local_visible_publicamente() pero la policy de SELECT de la propia
-- tabla `locales` tenía su PROPIA condición hardcodeada
-- (estado in ('trial','activo','gracia')), separada de esa función —
-- por eso un local suspendido seguía sin verse pese al cambio. Se
-- unifica para que dependa de la misma función que ya usan
-- categorias/productos/combos/etc., y quede un solo lugar para tocar
-- esto a futuro.
alter policy locales_select on locales
  using (local_visible_publicamente(id) or tiene_acceso_local(id));
