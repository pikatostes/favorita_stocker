-- ============================================================================
-- 0012 — Stock de terraza
--
-- La terraza lleva su propio conteo de botellines: `unit_in_terrace_stock`.
-- Al guardar la lista de la planta Terraza se descuenta de este campo en vez de
-- `unit_in_stock` (que queda para el resto del local). El resto de plantas
-- sigue funcionando igual.
--
-- El admin puede cargar o corregir el conteo desde Inventario → Terraza; las
-- listas lo mueven solas.
-- ============================================================================

alter table public.product
  add column if not exists unit_in_terrace_stock int not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'product_terrace_stock_check'
      and conrelid = 'public.product'::regclass
  ) then
    alter table public.product
      add constraint product_terrace_stock_check
      check (unit_in_terrace_stock >= 0);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- product_view: el modelo Dart lee las columnas planas de aquí
-- ---------------------------------------------------------------------------

create or replace view public.product_view
with (security_invoker = true) as
select
  p.id,
  p.name,
  p.image,
  p.unit_in_stock,
  p.deleted_at,
  g.image as group_image,
  c.name as category,
  g.name as group_name,
  s.name as subcategory,
  b.type as box_name,
  b.units_per_box,
  b.size,
  b.height,
  b.width,
  b.format,
  b.trip_capacity,
  p.unit_in_terrace_stock
from public.product p
join public.product_group g on g.id = p.group_id
join public.category c on c.id = g.category_id
left join public.subcategory s on s.id = p.subcategory_id
join public.box_type b on b.id = p.box_id;

-- ---------------------------------------------------------------------------
-- Ajuste manual del stock de terraza (solo administradores)
-- ---------------------------------------------------------------------------

create or replace function public.adjust_product_terrace_stock(
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
    select unit_in_terrace_stock into v_stock
      from public.product
     where id = p_product_id;
    if v_stock is null then
      raise exception 'Producto no encontrado';
    end if;
    return v_stock;
  end if;

  select unit_in_terrace_stock into v_stock
    from public.product
   where id = p_product_id
   for update;

  if v_stock is null then
    raise exception 'Producto no encontrado';
  end if;
  if v_stock + p_delta < 0 then
    raise exception 'El stock de terraza no puede quedar por debajo de cero';
  end if;

  update public.product
     set unit_in_terrace_stock = v_stock + p_delta,
         updated_at = now()
   where id = p_product_id;

  return v_stock + p_delta;
end $$;

-- ---------------------------------------------------------------------------
-- save_night: la lista de terraza mueve su propio stock
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
  v_terrace boolean;
  v_missing text;
begin
  if public.current_profile_id() is null then
    raise exception 'Sesión no válida o cuenta desactivada';
  end if;
  if v_floor not in ('planta_baja', 'karaoke', 'terraza') then
    raise exception 'La planta no es válida';
  end if;
  v_terrace := v_floor = 'terraza';

  select id into v_night_id
    from public.night
   where date = p_date and floor = v_floor
   for update;

  if v_night_id is null then
    insert into public.night (date, floor)
    values (p_date, v_floor)
    returning id into v_night_id;
  else
    -- Guardar una lista nueva reabre la jornada finalizada.
    update public.night
       set finalized_at = null
     where id = v_night_id;
  end if;

  -- El stock disponible debe cubrir la nueva lista una vez devuelto lo que
  -- consumía la lista anterior de esta misma noche y planta. La terraza mira
  -- su propio stock; el resto de plantas, el general.
  if v_terrace then
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
       and p.unit_in_terrace_stock + coalesce(prev_cons.quantity, 0)
           < coalesce(next_cons.quantity, 0)
     limit 1;
  else
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
  end if;

  if v_missing is not null then
    if v_terrace then
      raise exception 'Stock insuficiente en terraza para %', v_missing;
    end if;
    raise exception 'Stock insuficiente para %', v_missing;
  end if;

  if v_terrace then
    -- Devuelve a la terraza lo que consumía su lista anterior y descuenta la
    -- nueva. El stock general no se toca.
    update public.product p
       set unit_in_terrace_stock = p.unit_in_terrace_stock + d.delta,
           updated_at = now()
      from (
        select product_id, sum(delta)::int as delta
          from (
            select product_id, sum(quantity)::int as delta
              from public.consumption
             where night_id = v_night_id
             group by product_id
            union all
            select (e->>'product_id')::bigint,
                   -sum((e->>'quantity')::int) as delta
              from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
             where (e->>'quantity')::int > 0
             group by 1
          ) x
         group by product_id
      ) d
     where p.id = d.product_id;
  else
    -- Devuelve al stock general lo que tenía la lista anterior.
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

    -- Descuenta del stock general la lista nueva.
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
-- Permisos
-- ---------------------------------------------------------------------------

revoke all on function public.adjust_product_terrace_stock(bigint, int)
  from public, anon;
grant execute on function public.adjust_product_terrace_stock(bigint, int)
  to authenticated;

revoke all on function public.save_night(date, text, jsonb)
  from public, anon;
grant execute on function public.save_night(date, text, jsonb)
  to authenticated;

-- Comprobación: productos con stock de terraza.
select p.id,
       p.name,
       p.unit_in_stock as stock_general,
       p.unit_in_terrace_stock as stock_terraza
from public.product p
where p.deleted_at is null
  and p.unit_in_terrace_stock > 0
order by p.name;
