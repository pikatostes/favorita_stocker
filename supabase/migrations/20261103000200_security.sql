-- ============================================================================
-- 0002 — Grants, RLS y alta automática de perfiles
--
-- Postgres comprueba primero los privilegios de tabla y después la RLS.
-- Por eso no basta con crear políticas: hay que conceder permisos al rol
-- "authenticated". El rol "anon" no recibe nada: la app es interna.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helpers de autorización
-- ---------------------------------------------------------------------------

create or replace function public.current_profile_id()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.profiles
  where auth_id = auth.uid() and active
  limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where auth_id = auth.uid() and active and role = 'admin'
  );
$$;

revoke all on function public.current_profile_id() from public, anon;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.current_profile_id() to authenticated;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- Perfil automático al crear una cuenta en Supabase Auth
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (auth_id, name, surname, email)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'name', ''), 'Usuario'),
    coalesce(new.raw_user_meta_data->>'surname', ''),
    coalesce(new.email, '')
  )
  on conflict (auth_id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on schema public from anon;
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;

grant usage on schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Lectura: catálogo, personas, turnos y consumo
grant select on
  public.category,
  public.box_type,
  public.product_group,
  public.subcategory,
  public.product,
  public.job_role,
  public.special_day,
  public.profiles,
  public.shift,
  public.night,
  public.consumption
to authenticated;

-- Vistas de lectura
grant select on
  public.product_view,
  public.product_group_view,
  public.subcategory_view,
  public.user_view
to authenticated;

-- Escritura directa: la RLS la limita a administradores.
-- night y consumption NO la tienen: solo se escriben por RPC.
grant insert, update, delete on
  public.category,
  public.box_type,
  public.product_group,
  public.subcategory,
  public.product,
  public.job_role,
  public.special_day,
  public.profiles,
  public.shift
to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.category enable row level security;
alter table public.box_type enable row level security;
alter table public.product_group enable row level security;
alter table public.subcategory enable row level security;
alter table public.product enable row level security;
alter table public.night enable row level security;
alter table public.consumption enable row level security;
alter table public.special_day enable row level security;
alter table public.job_role enable row level security;
alter table public.profiles enable row level security;
alter table public.shift enable row level security;

-- Catálogo: todos leen; solo admin escribe.
do $$
declare
  t text;
begin
  foreach t in array array[
    'category', 'box_type', 'product_group', 'subcategory', 'product', 'job_role'
  ] loop
    execute format('drop policy if exists %I_read on public.%I', t, t);
    execute format(
      'create policy %I_read on public.%I
       for select to authenticated using (true)', t, t);

    execute format('drop policy if exists %I_admin_write on public.%I', t, t);
    execute format(
      'create policy %I_admin_write on public.%I
       for all to authenticated
       using (public.is_admin())
       with check (public.is_admin())', t, t);
  end loop;
end $$;

-- Excepciones de calendario.
drop policy if exists special_day_read on public.special_day;
create policy special_day_read on public.special_day
  for select to authenticated using (true);

drop policy if exists special_day_admin_write on public.special_day;
create policy special_day_admin_write on public.special_day
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Consumo: solo lectura directa; la escritura va por save_night().
drop policy if exists night_read on public.night;
create policy night_read on public.night
  for select to authenticated using (true);

drop policy if exists consumption_read on public.consumption;
create policy consumption_read on public.consumption
  for select to authenticated using (true);

-- Perfiles: el equipo se ve entre sí para turnos y avisos.
-- La escritura directa queda reservada al admin; cada usuario actualiza sus
-- datos por la RPC update_own_profile().
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles
  for select to authenticated using (true);

drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Turnos: el empleado ve publicados y confirmados; el admin ve todo.
drop policy if exists shift_read on public.shift;
create policy shift_read on public.shift
  for select to authenticated
  using (public.is_admin() or status <> 'borrador');

drop policy if exists shift_admin_write on public.shift;
create policy shift_admin_write on public.shift
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

do $$
begin
  begin
    alter publication supabase_realtime add table
      public.category,
      public.box_type,
      public.product_group,
      public.subcategory,
      public.product,
      public.night,
      public.consumption,
      public.special_day,
      public.job_role,
      public.profiles,
      public.shift;
  exception
    when duplicate_object then null;
  end;
end $$;
