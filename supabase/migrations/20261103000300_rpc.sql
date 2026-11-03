-- ============================================================================
-- 0003 — Operaciones transaccionales (RPC)
--
-- Solo se mueven al servidor las operaciones que deben ser atómicas o que
-- necesitan saltarse la RLS de forma controlada. El cálculo de previsión,
-- el planificador y el generador de turnos siguen en Flutter.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Catálogo: alta/edición de producto + imagen de grupo
-- ---------------------------------------------------------------------------

create or replace function public.save_product(
  p_id bigint,
  p_name text,
  p_category text,
  p_group text,
  p_subcategory text,
  p_box jsonb,
  p_image text,
  p_group_image text,
  p_unit_in_stock int
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category_id bigint;
  v_group_id bigint;
  v_subcategory_id bigint;
  v_box_id bigint;
  v_id bigint;
  v_now timestamptz := now();
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede guardar productos';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'El nombre del producto es obligatorio';
  end if;
  if coalesce(trim(p_group), '') = '' then
    raise exception 'El grupo de variantes es obligatorio';
  end if;

  insert into public.category (name)
  values (coalesce(nullif(trim(p_category), ''), 'Otros'))
  on conflict (name) do update set name = excluded.name
  returning id into v_category_id;

  insert into public.product_group (category_id, name)
  values (v_category_id, trim(p_group))
  on conflict (category_id, name) do update set updated_at = v_now
  returning id into v_group_id;

  if coalesce(trim(p_subcategory), '') <> '' then
    insert into public.subcategory (group_id, name)
    values (v_group_id, trim(p_subcategory))
    on conflict (group_id, name) do update set name = excluded.name
    returning id into v_subcategory_id;
  else
    v_subcategory_id := null;
  end if;

  insert into public.box_type (
    type, units_per_box, size, height, width, format, trip_capacity
  )
  values (
    coalesce(nullif(trim(p_box->>'type'), ''), 'Caja'),
    greatest((p_box->>'units')::int, 1),
    greatest((p_box->>'size')::double precision, 0.01),
    greatest((p_box->>'height')::double precision, 0.01),
    greatest((p_box->>'width')::double precision, 0.01),
    greatest((p_box->>'format')::int, 1),
    greatest((p_box->>'trip')::int, 1)
  )
  on conflict (type) do update set
    units_per_box = excluded.units_per_box,
    size = excluded.size,
    height = excluded.height,
    width = excluded.width,
    format = excluded.format,
    trip_capacity = excluded.trip_capacity,
    updated_at = v_now
  returning id into v_box_id;

  if p_id is null then
    insert into public.product (
      name, box_id, group_id, subcategory_id, image, unit_in_stock
    )
    values (
      trim(p_name), v_box_id, v_group_id, v_subcategory_id, p_image,
      greatest(coalesce(p_unit_in_stock, 0), 0)
    )
    returning id into v_id;
  else
    update public.product set
      name = trim(p_name),
      box_id = v_box_id,
      group_id = v_group_id,
      subcategory_id = v_subcategory_id,
      image = p_image,
      unit_in_stock = greatest(coalesce(p_unit_in_stock, 0), 0),
      updated_at = v_now
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'Producto no encontrado';
    end if;
  end if;

  if p_group_image is not null then
    update public.product_group
       set image = nullif(trim(p_group_image), ''), updated_at = v_now
     where id = v_group_id;
  end if;

  return v_id;
end $$;

create or replace function public.set_group_image(
  p_category text,
  p_group text,
  p_image text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category_id bigint;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede cambiar imágenes';
  end if;
  if coalesce(trim(p_category), '') = '' or coalesce(trim(p_group), '') = '' then
    raise exception 'La categoría y el grupo son obligatorios';
  end if;

  insert into public.category (name)
  values (trim(p_category))
  on conflict (name) do update set name = excluded.name
  returning id into v_category_id;

  insert into public.product_group (category_id, name, image)
  values (v_category_id, trim(p_group), nullif(trim(p_image), ''))
  on conflict (category_id, name) do update set
    image = excluded.image,
    updated_at = now();
end $$;

-- ---------------------------------------------------------------------------
-- Consumo de una noche
-- ---------------------------------------------------------------------------

create or replace function public.save_night(
  p_date date,
  p_items jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_night_id bigint;
begin
  if public.current_profile_id() is null then
    raise exception 'Sesión no válida o cuenta desactivada';
  end if;

  select id into v_night_id from public.night where date = p_date;

  if v_night_id is null then
    insert into public.night (date) values (p_date)
    returning id into v_night_id;
  end if;

  delete from public.consumption where night_id = v_night_id;

  insert into public.consumption (night_id, product_id, quantity)
  select
    v_night_id,
    (e->>'product_id')::bigint,
    (e->>'quantity')::int
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
  where (e->>'quantity')::int > 0;
end $$;

-- ---------------------------------------------------------------------------
-- Turnos
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
    date, user_id, user_name, role_id, role_name, floor,
    start_min, end_min, break_min, status, note
  )
  select
    (e->>'date')::date,
    (e->>'user_id')::bigint,
    e->>'user_name',
    (e->>'role_id')::bigint,
    e->>'role_name',
    e->>'floor',
    (e->>'start_min')::int,
    (e->>'end_min')::int,
    coalesce((e->>'break_min')::int, 0),
    coalesce(e->>'status', 'borrador'),
    nullif(e->>'note', '')
  from jsonb_array_elements(coalesce(p_shifts, '[]'::jsonb)) e;
end $$;

create or replace function public.publish_month(p_month date)
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
    raise exception 'Solo un administrador puede publicar turnos';
  end if;

  update public.shift
     set status = 'publicado'
   where date between v_first and v_last
     and status = 'borrador';
end $$;

create or replace function public.confirm_my_shift(p_shift_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.shift
     set status = 'confirmado'
   where id = p_shift_id
     and status = 'publicado'
     and (
       public.is_admin()
       or user_id = public.current_profile_id()
     );

  if not found then
    raise exception 'Turno no encontrado o no confirmable';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Perfil propio
-- ---------------------------------------------------------------------------

create or replace function public.update_own_profile(
  p_name text,
  p_surname text
)
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

  update public.profiles
     set name = coalesce(nullif(trim(p_name), ''), name),
         surname = coalesce(p_surname, surname)
   where id = v_id;
end $$;

create or replace function public.mark_password_changed()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint := public.current_profile_id();
begin
  if v_id is null then
    return;
  end if;

  update public.profiles
     set must_change_password = false
   where id = v_id;
end $$;

-- ---------------------------------------------------------------------------
-- Mantenimiento e importación
-- ---------------------------------------------------------------------------

create or replace function public.purge_old_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.consumption
   where night_id in (
     select id from public.night
      where date < current_date - interval '2 years'
   );
  delete from public.night
   where date < current_date - interval '2 years';
  delete from public.special_day
   where date < current_date - interval '2 years';
  delete from public.shift
   where date < current_date - interval '2 years';
end $$;

-- Reajusta las secuencias después de importar ids explícitos desde SQLite.
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
    'night', 'consumption', 'job_role', 'shift'
  ] loop
    seq := pg_get_serial_sequence('public.' || t, 'id');
    execute format('select coalesce(max(id), 0) from public.%I', t)
      into max_id;
    if max_id > 0 then
      perform setval(seq::regclass, max_id);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Permisos de ejecución
-- ---------------------------------------------------------------------------

revoke all on function public.save_product(
  bigint, text, text, text, text, jsonb, text, text, int
) from public, anon;
grant execute on function public.save_product(
  bigint, text, text, text, text, jsonb, text, text, int
) to authenticated;

revoke all on function public.set_group_image(text, text, text)
  from public, anon;
grant execute on function public.set_group_image(text, text, text)
  to authenticated;

revoke all on function public.save_night(date, jsonb) from public, anon;
grant execute on function public.save_night(date, jsonb) to authenticated;

revoke all on function public.replace_month_shifts(date, jsonb)
  from public, anon;
grant execute on function public.replace_month_shifts(date, jsonb)
  to authenticated;

revoke all on function public.publish_month(date) from public, anon;
grant execute on function public.publish_month(date) to authenticated;

revoke all on function public.confirm_my_shift(bigint) from public, anon;
grant execute on function public.confirm_my_shift(bigint) to authenticated;

revoke all on function public.update_own_profile(text, text)
  from public, anon;
grant execute on function public.update_own_profile(text, text)
  to authenticated;

revoke all on function public.mark_password_changed() from public, anon;
grant execute on function public.mark_password_changed() to authenticated;

-- Estas dos solo las usa el mantenimiento o la importación con clave secreta.
revoke all on function public.purge_old_data() from public, anon, authenticated;
grant execute on function public.purge_old_data() to service_role;

revoke all on function public.reset_sequences()
  from public, anon, authenticated;
grant execute on function public.reset_sequences() to service_role;
