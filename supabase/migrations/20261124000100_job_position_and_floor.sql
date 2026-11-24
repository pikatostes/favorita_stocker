-- ============================================================================
-- Puestos fijos y planta habitual
--
-- Sustituye el catálogo configurable `job_role` por dos conceptos separados:
--
--   * `job_position`: puesto habitual del empleado. Solo existen dos valores,
--     `camarero` y `manteni`.
--   * `floor`: planta del local. Solo existen `planta_baja`, `karaoke` y
--     `terraza`.
--
-- Cada perfil guarda su planta habitual (`profiles.floor`) y su puesto
-- habitual (`profiles.job_position`). Los turnos guardan la planta en la que se
-- trabaja (`shift.floor`) y el puesto del turno (`shift.position` +
-- `shift.position_name`), que puede editarse después de generarlo.
--
-- El puesto `manteni` se fuerza siempre a planta baja mediante un trigger.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Catálogos fijos
-- ---------------------------------------------------------------------------

create table if not exists public.floor (
  key text primary key
    check (key in ('planta_baja', 'karaoke', 'terraza')),
  name text not null
);

insert into public.floor (key, name) values
  ('planta_baja', 'Planta baja'),
  ('karaoke', 'Karaoke'),
  ('terraza', 'Terraza')
on conflict (key) do nothing;

create table if not exists public.job_position (
  key text primary key
    check (key in ('camarero', 'manteni')),
  name text not null
);

insert into public.job_position (key, name) values
  ('camarero', 'Camarero'),
  ('manteni', 'Manteni')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Perfiles: planta y puesto habituales
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists floor text,
  add column if not exists job_position text;

-- Migración de datos desde el antiguo `job_role`.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'job_role_id'
  ) and exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'job_role'
  ) then
    update public.profiles p
       set floor = coalesce(r.floor, p.floor, 'planta_baja'),
           job_position = case
             when lower(coalesce(r.name_key, '')) in ('manteni', 'mantenimiento')
               then 'manteni'
             else 'camarero'
           end
      from public.job_role r
     where r.id = p.job_role_id;
  end if;
end $$;

update public.profiles set floor = 'planta_baja' where floor is null;
update public.profiles
   set job_position = null
 where job_position is not null
   and job_position not in ('camarero', 'manteni');

alter table public.profiles
  alter column floor set default 'planta_baja',
  alter column floor set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_floor_fkey'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_floor_fkey
      foreign key (floor) references public.floor(key);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_job_position_fkey'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_job_position_fkey
      foreign key (job_position) references public.job_position(key);
  end if;
end $$;

-- Manteni trabaja siempre en planta baja, se elija la planta que se elija.
create or replace function public.enforce_maintenance_floor()
returns trigger
language plpgsql
as $$
begin
  if new.job_position = 'manteni' then
    new.floor := 'planta_baja';
  end if;
  return new;
end $$;

drop trigger if exists trg_profiles_maintenance_floor on public.profiles;
create trigger trg_profiles_maintenance_floor
before insert or update of job_position, floor on public.profiles
for each row execute function public.enforce_maintenance_floor();

-- ---------------------------------------------------------------------------
-- Turnos: planta y puesto del turno
-- ---------------------------------------------------------------------------

alter table public.shift
  add column if not exists position text,
  add column if not exists position_name text;

-- Migración de datos desde `role_name`.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'shift'
      and column_name = 'role_name'
  ) then
    update public.shift s
       set position = case
             when lower(coalesce(s.role_name, '')) in ('manteni', 'mantenimiento')
               then 'manteni'
             else 'camarero'
           end,
           position_name = coalesce(nullif(s.role_name, ''), 'Camarero')
     where s.position is null
        or s.position_name is null
        or s.position_name = '';
  end if;
end $$;

update public.shift set position = 'camarero' where position is null;
update public.shift set position_name = 'Camarero' where position_name is null;

alter table public.shift
  alter column position set not null,
  alter column position_name set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'shift_position_check'
      and conrelid = 'public.shift'::regclass
  ) then
    alter table public.shift
      add constraint shift_position_check
      check (position in ('camarero', 'manteni'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'shift_position_fkey'
      and conrelid = 'public.shift'::regclass
  ) then
    alter table public.shift
      add constraint shift_position_fkey
      foreign key (position) references public.job_position(key);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Retirada del catálogo antiguo
--
-- `user_view` depende de `profiles.job_role_id` y de la tabla `job_role`, así
-- que hay que eliminarla antes de borrar las columnas. Se vuelve a crear más
-- abajo con las columnas nuevas.
-- ---------------------------------------------------------------------------

drop view if exists public.user_view;

alter table public.profiles drop column if exists job_role_id;
alter table public.shift drop column if exists role_id;
alter table public.shift drop column if exists role_name;
drop table if exists public.job_role;

-- ---------------------------------------------------------------------------
-- Vista de lectura
-- ---------------------------------------------------------------------------

create view public.user_view
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
  u.floor,
  u.job_position,
  p.name as job_position_name,
  u.avatar_path
from public.profiles u
left join public.job_position p on p.key = u.job_position;

grant select on public.user_view to authenticated;

-- ---------------------------------------------------------------------------
-- RPC de turnos
-- ---------------------------------------------------------------------------

create or replace function public.replace_month_shifts(
  p_month date,
  p_shifts jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_first date := date_trunc('month', p_month)::date;
  v_last date := (date_trunc('month', p_month) + interval '1 month - 1 day')::date;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede regenerar turnos';
  end if;

  delete from public.shift where date between v_first and v_last;

  insert into public.shift (
    date, user_id, user_name, position, position_name, floor,
    start_min, end_min, break_min, status, note
  )
  select
    (e->>'date')::date,
    (e->>'user_id')::bigint,
    e->>'user_name',
    coalesce(nullif(e->>'position', ''), 'camarero'),
    coalesce(nullif(e->>'position_name', ''), 'Camarero'),
    e->>'floor',
    (e->>'start_min')::int,
    (e->>'end_min')::int,
    coalesce((e->>'break_min')::int, 0),
    coalesce(e->>'status', 'borrador'),
    nullif(e->>'note', '')
  from jsonb_array_elements(coalesce(p_shifts, '[]'::jsonb)) e;
end $$;

revoke all on function public.replace_month_shifts(date, jsonb)
  from public, anon;
grant execute on function public.replace_month_shifts(date, jsonb)
  to authenticated;

-- `job_role` desaparece: ya no hay secuencia que reajustar para los puestos.
create or replace function public.reset_sequences()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  t text;
  seq text;
  max_id bigint;
begin
  foreach t in array array[
    'category', 'box_type', 'product_group', 'subcategory', 'product',
    'night', 'consumption', 'shift'
  ] loop
    seq := pg_get_serial_sequence('public.' || t, 'id');
    execute format('select coalesce(max(id), 0) from public.%I', t)
      into max_id;
    if max_id > 0 then
      perform setval(seq::regclass, max_id);
    end if;
  end loop;
end $$;

revoke all on function public.reset_sequences()
  from public, anon, authenticated;
grant execute on function public.reset_sequences() to service_role;

-- ---------------------------------------------------------------------------
-- Grants, RLS y Realtime de los catálogos nuevos
-- ---------------------------------------------------------------------------

grant select on public.floor, public.job_position to authenticated;

alter table public.floor enable row level security;
alter table public.job_position enable row level security;

drop policy if exists floor_read on public.floor;
create policy floor_read on public.floor
  for select to authenticated using (true);

drop policy if exists job_position_read on public.job_position;
create policy job_position_read on public.job_position
  for select to authenticated using (true);

do $$
begin
  alter publication supabase_realtime add table public.floor;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.job_position;
exception
  when duplicate_object then null;
end $$;

notify pgrst, 'reload schema';
