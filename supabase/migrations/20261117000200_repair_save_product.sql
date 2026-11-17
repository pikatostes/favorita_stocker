-- ============================================================================
-- 0016 — Reparar `save_product` y refrescar el esquema de la API
--
-- Síntoma: al guardar un producto, la app recibe
--   «Could not find the function public.save_product(p_box, p_category, …)
--    in the schema cache»
--
-- El cliente envía exactamente los 9 parámetros de siempre, así que el fallo
-- está en la base de datos: o PostgREST tiene la caché de esquema desfasada, o
-- quedó una versión de `save_product` con otra firma (por ejemplo, de un
-- proyecto provisionado con una versión anterior). Esta migración:
--
--   1. elimina cualquier sobrecarga de `save_product` en `public`;
--   2. vuelve a crear la versión canónica (la misma de 0011, que no pisa el
--      stock al editar);
--   3. reaplica los permisos;
--   4. pide a PostgREST que recargue el esquema.
--
-- Es idempotente: se puede ejecutar varias veces sin efectos secundarios.
-- ============================================================================

-- 1) Fuera cualquier versión previa, sea cual sea su firma.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as firma
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'save_product'
  loop
    execute format('drop function %s cascade', r.firma);
  end loop;
end $$;

-- 2) Versión canónica: crea o edita el producto y su catálogo, sin tocar el
--    stock al editar.
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

-- 3) Permisos: solo usuarios autenticados.
revoke all on function public.save_product(
  bigint, text, text, text, text, jsonb, text, text, int
) from public, anon;
grant execute on function public.save_product(
  bigint, text, text, text, text, jsonb, text, text, int
) to authenticated;

-- 4) Recarga de la caché de esquema de PostgREST.
notify pgrst, 'reload schema';

-- Comprobación: debe devolver una única firma con los 9 parámetros p_*.
select p.oid::regprocedure as firma,
       pg_get_function_identity_arguments(p.oid) as argumentos
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'save_product';
