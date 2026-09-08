-- Suspensión manual de un local desde el panel de super-admin (además de la
-- automática por vencimiento que hace el cron).
create or replace function suspender_local(p_local_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not es_super_admin() then
    raise exception 'Solo el super-admin puede suspender un local';
  end if;
  update locales set estado = 'suspendido' where id = p_local_id;
  if not found then
    raise exception 'Local no encontrado';
  end if;
end;
$$;

revoke execute on function suspender_local(uuid) from public;
grant execute on function suspender_local(uuid) to authenticated;
