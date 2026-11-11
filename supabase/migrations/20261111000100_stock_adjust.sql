-- ============================================================================
-- 0006 — Ajuste de stock y descuento automático de la lista
--
-- El stock de cada producto se guarda en `product.unit_in_stock` (botellines).
-- El administrador puede subirlo o bajarlo manualmente y, al guardar una lista
-- de noche, el consumo se descuenta del stock. Las listas editadas ajustan solo
-- la diferencia respecto a lo que ya había guardado, de modo que volver a
-- guardar la misma lista no mueve el stock.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Ajuste manual de stock (solo administradores)
-- ---------------------------------------------------------------------------

create or replace function public.adjust_product_stock(
  p_product_id bigint,
  p_delta int
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stock int;
begin
  if not public.is_admin() then
    raise exception 'Solo un administrador puede cambiar el stock';
  end if;
  if p_delta is null or p_delta = 0 then
    select unit_in_stock into v_stock
      from public.product
     where id = p_product_id;
    if v_stock is null then
      raise exception 'Producto no encontrado';
    end if;
    return v_stock;
  end if;

  select unit_in_stock into v_stock
    from public.product
   where id = p_product_id
   for update;

  if v_stock is null then
    raise exception 'Producto no encontrado';
  end if;
  if v_stock + p_delta < 0 then
    raise exception 'El stock no puede quedar por debajo de cero';
  end if;

  update public.product
     set unit_in_stock = v_stock + p_delta,
         updated_at = now()
   where id = p_product_id;

  return v_stock + p_delta;
end $$;

-- ---------------------------------------------------------------------------
-- El catálogo ya no pisa el stock al editar un producto
--
-- El stock se mueve con `adjust_product_stock` y con la lista de noche. Si
-- `save_product` lo escribiera con el valor que tenía la pantalla al abrirse,
-- una edición de nombre/categoría podría revertir un ajuste reciente.
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

-- ---------------------------------------------------------------------------
-- Lista de noche: descuenta del stock solo la diferencia
-- ---------------------------------------------------------------------------

create or replace function public.save_night(
  p_date date,
  p_floor text,
  p_items jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_night_id bigint;
  v_floor text := coalesce(nullif(trim(p_floor), ''), 'planta_baja');
  v_missing text;
begin
  if public.current_profile_id() is null then
    raise exception 'Sesión no válida o cuenta desactivada';
  end if;
  if v_floor not in ('planta_baja', 'karaoke', 'terraza') then
    raise exception 'La planta no es válida';
  end if;

  select id into v_night_id
    from public.night
   where date = p_date and floor = v_floor
   for update;

  if v_night_id is null then
    insert into public.night (date, floor)
    values (p_date, v_floor)
    returning id into v_night_id;
  end if;

  -- El stock disponible debe cubrir la nueva lista una vez devuelto lo que
  -- consumía la lista anterior de esta misma noche y planta.
  select p.name into v_missing
    from public.product p
    left join (
      select product_id, sum(quantity)::int as quantity
        from public.consumption
       where night_id = v_night_id
       group by product_id
    ) prev_cons on prev_cons.product_id = p.id
    left join (
      select (e->>'product_id')::bigint as product_id,
             sum((e->>'quantity')::int) as quantity
        from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
       where (e->>'quantity')::int > 0
       group by 1
    ) next_cons on next_cons.product_id = p.id
   where (prev_cons.product_id is not null or next_cons.product_id is not null)
     and p.unit_in_stock + coalesce(prev_cons.quantity, 0)
         < coalesce(next_cons.quantity, 0)
   limit 1;

  if v_missing is not null then
    raise exception 'Stock insuficiente para %', v_missing;
  end if;

  -- Devuelve al stock lo que tenía la lista anterior.
  update public.product p
     set unit_in_stock = p.unit_in_stock + o.quantity,
         updated_at = now()
    from (
      select product_id, sum(quantity)::int as quantity
        from public.consumption
       where night_id = v_night_id
       group by product_id
    ) o
   where p.id = o.product_id;

  delete from public.consumption where night_id = v_night_id;

  insert into public.consumption (night_id, product_id, quantity)
  select
    v_night_id,
    (e->>'product_id')::bigint,
    (e->>'quantity')::int
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
  where (e->>'quantity')::int > 0;

  -- Descuenta del stock la lista nueva.
  update public.product p
     set unit_in_stock = p.unit_in_stock - n.quantity,
         updated_at = now()
    from (
      select (e->>'product_id')::bigint as product_id,
             sum((e->>'quantity')::int) as quantity
        from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
       where (e->>'quantity')::int > 0
       group by 1
    ) n
   where p.id = n.product_id;
end $$;

-- ---------------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------------

revoke all on function public.adjust_product_stock(bigint, int)
  from public, anon;
grant execute on function public.adjust_product_stock(bigint, int)
  to authenticated;

revoke all on function public.save_night(date, text, jsonb)
  from public, anon;
grant execute on function public.save_night(date, text, jsonb)
  to authenticated;
