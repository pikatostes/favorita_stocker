-- ============================================================================
-- 0013 — Inventario de botellas de alcohol
--
-- Las botellas se guardan como productos de la categoría «Alcohol» con un tipo
-- de caja propio («Botella», 1 unidad por caja). Así reutilizan la Lista, el
-- descuento de stock de `save_night`, el stock de terraza, el Inventario y el
-- ajuste manual sin duplicar lógica.
--
-- `box_type.is_bottle` marca esos tipos para que la UI hable de botellas (no de
-- cajas) y para excluirlos del plan de montaje y de la previsión.
-- ============================================================================

alter table public.box_type
  add column if not exists is_bottle boolean not null default false;

-- Tipo de caja de una botella: se cuenta de una en una. No se pisa nada más
-- del tipo si ya existiera; solo se garantiza que sea de botellas y de 1 ud.
insert into public.box_type (
  type, units_per_box, size, height, width, format, trip_capacity, is_bottle
)
values ('Botella', 1, 1, 1, 1, 1, 24, true)
on conflict (type) do update set
  units_per_box = 1,
  is_bottle = true;

insert into public.category (name)
values ('Alcohol')
on conflict (name) do nothing;

-- Un tipo de caja de botellas siempre cuenta de una en una, aunque alguien
-- cambie las unidades por caja al editar un producto (`save_product` hace
-- upsert del tipo de caja). Se normaliza en silencio para no romper el alta.
create or replace function public.normalize_bottle_box()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.is_bottle then
    new.units_per_box := 1;
  end if;
  return new;
end $$;

drop trigger if exists box_type_normalize_bottle on public.box_type;
create trigger box_type_normalize_bottle
  before insert or update on public.box_type
  for each row execute function public.normalize_bottle_box();

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
  p.unit_in_terrace_stock,
  b.is_bottle
from public.product p
join public.product_group g on g.id = p.group_id
join public.category c on c.id = g.category_id
left join public.subcategory s on s.id = p.subcategory_id
join public.box_type b on b.id = p.box_id;

-- Comprobación: tipos de caja de botellas y productos que las usan.
select b.type,
       b.units_per_box,
       b.is_bottle,
       count(p.id) as productos
from public.box_type b
left join public.product p on p.box_id = b.id and p.deleted_at is null
where b.is_bottle
group by b.type, b.units_per_box, b.is_bottle;
