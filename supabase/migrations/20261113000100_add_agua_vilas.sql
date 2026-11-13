-- ============================================================================
-- 0008 — Alta de «Agua de cristal Vilas» en el catálogo
--
-- Comprobación del modelo: no existe una tabla de productos plana. `product`
-- necesita categoría (vía `product_group`), grupo y tipo de caja. Como este
-- agua no tiene variantes, se crea un grupo con su mismo nombre y sin
-- subcategoría: `buildProductEntries` lo muestra como producto suelto.
--
-- Se reutiliza la caja `Agua` (20 uds, 2/1/1, formato 3, 5 por viaje) que ya
-- usa `Agua Aquabona`, para no crear un box_type nuevo. El stock arranca en 0;
-- el stock real se ajusta desde Admin → Inventario.
--
-- Idempotente: se puede ejecutar varias veces sin duplicar el producto.
-- ============================================================================

begin;

-- La caja debe existir antes que el producto. En una base creada solo con las
-- migraciones (sin seed_catalog.sql) todavía no está, así que se crea con los
-- mismos valores que la semilla.
insert into public.box_type
  (type, units_per_box, size, height, width, format, trip_capacity)
values
  ('Agua', 20, 2, 1, 1, 3, 5)
on conflict (type) do nothing;

insert into public.category (name)
values ('Refrescos y zumos')
on conflict (name) do nothing;

-- Grupo propio y sin subcategoría: el producto se muestra suelto.
insert into public.product_group (category_id, name)
select c.id, 'Agua de cristal Vilas'
from public.category c
where c.name = 'Refrescos y zumos'
on conflict (category_id, name) do nothing;

insert into public.product
  (name, box_id, group_id, subcategory_id, image, unit_in_stock)
select
  'Agua de cristal Vilas',
  b.id,
  g.id,
  null,
  null,
  0
from public.product_group g
join public.category c on c.id = g.category_id
join public.box_type b on b.type = 'Agua'
where c.name = 'Refrescos y zumos'
  and g.name = 'Agua de cristal Vilas'
  and not exists (
    select 1
    from public.product p
    where p.group_id = g.id
      and p.name = 'Agua de cristal Vilas'
      and p.deleted_at is null
  );

commit;

-- Comprobación rápida en el SQL Editor.
select p.id,
       p.name,
       c.name as categoria,
       g.name as grupo,
       b.type as caja,
       b.units_per_box,
       p.unit_in_stock
from public.product p
join public.product_group g on g.id = p.group_id
join public.category c on c.id = g.category_id
join public.box_type b on b.id = p.box_id
where p.name = 'Agua de cristal Vilas'
  and p.deleted_at is null;
