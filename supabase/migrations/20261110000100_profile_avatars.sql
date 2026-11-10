-- ============================================================================
-- 0004 — Imágenes de perfil
--
-- La foto se guarda en Storage (bucket "avatars") y en profiles solo se
-- conserva la ruta del objeto. El bucket es público para poder usar
-- getPublicUrl() desde Flutter; la escritura queda limitada a la carpeta del
-- propio usuario (o a un administrador).
--
-- Ruta: avatars/<auth.uid()>/<timestamp>.jpg
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Columna en el perfil
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists avatar_path text;

-- ---------------------------------------------------------------------------
-- Vista de lectura
--
-- La columna se añade al final para que "create or replace view" sea válido.
-- ---------------------------------------------------------------------------

create or replace view public.user_view
with (security_invoker = true) as
select
  u.id,
  u.auth_id,
  u.name,
  u.surname,
  u.email,
  u.role,
  (u.active)::int as active,
  (u.opener)::int as opener,
  u.working_days,
  u.must_change_password,
  r.id as role_id,
  r.name as role_name,
  r.floor,
  r.note as role_note,
  u.avatar_path
from public.profiles u
left join public.job_role r on r.id = u.job_role_id;

-- ---------------------------------------------------------------------------
-- Bucket de Storage
--
-- Límite de 2 MB: el cliente reduce la imagen a 512 px antes de subirla.
-- ---------------------------------------------------------------------------

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'avatars',
  'avatars',
  true,
  2 * 1024 * 1024,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- Políticas de Storage
-- ---------------------------------------------------------------------------

-- Lectura para todo el equipo (el bucket es público, pero la política hace
-- falta para listar y para las comprobaciones de update/delete).
drop policy if exists avatars_read on storage.objects;
create policy avatars_read on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars');

-- Subir: solo a la carpeta propia.
drop policy if exists avatars_own_insert on storage.objects;
create policy avatars_own_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Reemplazar: solo la carpeta propia.
drop policy if exists avatars_own_update on storage.objects;
create policy avatars_own_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Borrar: solo la carpeta propia.
drop policy if exists avatars_own_delete on storage.objects;
create policy avatars_own_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Un administrador puede gestionar la foto de cualquier usuario.
drop policy if exists avatars_admin_all on storage.objects;
create policy avatars_admin_all on storage.objects
  for all to authenticated
  using (bucket_id = 'avatars' and public.is_admin())
  with check (bucket_id = 'avatars' and public.is_admin());

-- ---------------------------------------------------------------------------
-- Perfil propio: asignar o quitar la foto
--
-- La escritura directa sobre profiles sigue reservada al administrador; cada
-- usuario cambia su ruta por esta RPC.
-- ---------------------------------------------------------------------------

create or replace function public.set_own_avatar(p_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint := public.current_profile_id();
begin
  if v_id is null then
    raise exception 'Sesión no válida o cuenta desactivada';
  end if;

  -- Solo puede apuntar a su propia carpeta (o limpiar la foto).
  if p_path is not null
     and split_part(p_path, '/', 1) <> auth.uid()::text then
    raise exception 'Ruta de imagen no válida';
  end if;

  update public.profiles
     set avatar_path = nullif(trim(p_path), '')
   where id = v_id;
end $$;

revoke all on function public.set_own_avatar(text) from public, anon;
grant execute on function public.set_own_avatar(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Recargar la caché de esquema de PostgREST
-- ---------------------------------------------------------------------------

notify pgrst, 'reload schema';
