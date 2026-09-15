-- ============================================================
-- Rol "administrador": mismo poder que el dueño (equipo + config +
-- facturación + menú), pero el dueño es uno solo — el creador original
-- del local, vía registrar_negocio(). Un administrador se promueve desde
-- Equipo, nunca se crea como "dueño" nuevo.
--
-- Protección: como administrador == dueño en permisos (ambos pasan
-- es_dueño_local, y esa función guarda usuario_local_roles_write), un
-- administrador rogue podría en teoría sacar o degradar al dueño real.
-- Se bloquea con un trigger a nivel de base, no solo en el front — así
-- vale incluso si alguien pega directo contra la API.
-- ============================================================

alter table usuario_local_roles drop constraint usuario_local_roles_rol_check;
alter table usuario_local_roles add constraint usuario_local_roles_rol_check
  check (rol = any (array['dueño'::text, 'administrador'::text, 'staff'::text]));

create or replace function es_dueño_local(p_local_id uuid)
returns boolean
language sql stable as $$
  select rol_en_local(p_local_id) in ('dueño', 'administrador') or es_super_admin();
$$;

create or replace function proteger_dueño_local()
returns trigger
language plpgsql as $$
begin
  if TG_OP = 'DELETE' and OLD.rol = 'dueño' then
    raise exception 'No se puede quitar al dueño del local.';
  end if;
  if TG_OP = 'UPDATE' and OLD.rol = 'dueño' and NEW.rol is distinct from 'dueño' then
    raise exception 'No se puede cambiar el rol del dueño del local.';
  end if;
  return coalesce(NEW, OLD);
end;
$$;

drop trigger if exists usuario_local_roles_proteger_dueño on usuario_local_roles;
create trigger usuario_local_roles_proteger_dueño
  before update or delete on usuario_local_roles
  for each row execute function proteger_dueño_local();
