-- ============================================================================
-- Catálogo inicial: tipos de caja, categorías, grupos, variantes y stock.
--
-- Generado a partir de `lib/seed.dart` (initialProducts). Las cantidades de
-- `unit_in_stock` son datos de ejemplo para que el inventario no empiece a
-- cero; sustitúyelas por el stock real cuando lo tengas.
--
-- Es idempotente: se puede ejecutar varias veces en el SQL Editor sin crear
-- duplicados y sin pisar el stock de productos que ya existan.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- Tipos de caja (compartidos por varios productos)
-- ---------------------------------------------------------------------------
insert into public.box_type
  (type, units_per_box, size, height, width, format, trip_capacity)
values
  ('Cerveza', 24, 1, 1, 1, 2, 5),
  ('Cerveza grande', 24, 2, 1, 1, 2, 5),
  ('Cola', 24, 1, 0.5, 1, 1, 6),
  ('Nestea', 24, 1, 1, 1, 1, 5),
  ('Agua', 20, 2, 1, 1, 3, 5),
  ('Energética', 24, 2, 1, 1, 4, 5)
on conflict (type) do nothing;

-- ---------------------------------------------------------------------------
-- Datos de trabajo
-- ---------------------------------------------------------------------------
drop table if exists seed_catalog;

create temp table seed_catalog (
  name text not null,
  category text not null,
  grp text not null,
  subcategory text,
  image text,
  group_image text,
  box text not null,
  units int not null
);

insert into seed_catalog
  (name, category, grp, subcategory, image, group_image, box, units)
values
  ('Cruzcampo', 'Cervezas y similares', 'Cruzcampo', 'Pilsen', 'lib/img/cruzcampo.jfif', 'lib/img/cruzcampo.jfif', 'Cerveza', 132),
  ('1904', 'Cervezas y similares', 'Cruzcampo', '1904', 'lib/img/1904.png', 'lib/img/cruzcampo.jfif', 'Cerveza', 72),
  ('Cruzcampo Gran Reserva', 'Cervezas y similares', 'Cruzcampo', 'Gran Reserva', null, 'lib/img/cruzcampo.jfif', 'Cerveza', 54),
  ('Cruzcampo Radler', 'Cervezas y similares', 'Cruzcampo', 'Radler', null, 'lib/img/cruzcampo.jfif', 'Cerveza', 24),
  ('Cruzcampo Especial Sin Gluten', 'Cervezas y similares', 'Cruzcampo', 'Especial Sin Gluten', null, 'lib/img/cruzcampo.jfif', 'Cerveza', 0),
  ('Heineken', 'Cervezas y similares', 'Heineken', 'Normal', null, null, 'Cerveza', 114),
  ('Heineken 0,0', 'Cervezas y similares', 'Heineken', '0,0', null, null, 'Cerveza', 58),
  ('Amstel Tostada 0,0', 'Cervezas y similares', 'Otros', 'Amstel Tostada 0,0', 'lib/img/amstel00tostada.jpg', null, 'Cerveza', 29),
  ('Sol', 'Cervezas y similares', 'Otros', 'Sol', null, null, 'Cerveza', 72),
  ('Desperados', 'Cervezas y similares', 'Otros', 'Desperados', null, null, 'Cerveza', 36),
  ('Ladrón de manzanas', 'Cervezas y similares', 'Otros', 'Ladrón de manzanas', null, null, 'Cerveza', 51),
  ('Paulaner', 'Cervezas y similares', 'Otros', 'Paulaner', null, null, 'Cerveza grande', 52),
  ('Águila sin filtrar', 'Cervezas y similares', 'Otros', 'Águila sin filtrar', null, null, 'Cerveza grande', 32),
  ('Guinness', 'Cervezas y similares', 'Otros', 'Guinness', null, null, 'Cerveza', 18),
  ('Alcázar', 'Cervezas y similares', 'Otros', 'Alcázar', 'lib/img/alcazar.png', null, 'Cerveza', 24),
  ('Coca-Cola', 'Refrescos y zumos', 'Coca-Cola', 'Original', null, 'lib/img/coca-cola.png', 'Cola', 156),
  ('Coca-Cola Zero', 'Refrescos y zumos', 'Coca-Cola', 'Zero', null, 'lib/img/coca-cola.png', 'Cola', 120),
  ('Coca-Cola Zero Zero', 'Refrescos y zumos', 'Coca-Cola', 'Zero Zero', null, 'lib/img/coca-cola.png', 'Cola', 55),
  ('Coca-Cola Light', 'Refrescos y zumos', 'Coca-Cola', 'Light', null, 'lib/img/coca-cola.png', 'Cola', 44),
  ('Bliss', 'Refrescos y zumos', 'Bliss', 'Tónica', null, 'lib/img/royal-bliss.jpg', 'Cola', 76),
  ('Bliss Limón', 'Refrescos y zumos', 'Bliss', 'Limón', null, 'lib/img/royal-bliss.jpg', 'Cola', 24),
  ('Bliss Berry', 'Refrescos y zumos', 'Bliss', 'Berry', null, 'lib/img/royal-bliss.jpg', 'Cola', 15),
  ('Bliss Ginger Ale', 'Refrescos y zumos', 'Bliss', 'Ginger Ale', null, 'lib/img/royal-bliss.jpg', 'Cola', 56),
  ('Bliss Tónica Zero', 'Refrescos y zumos', 'Bliss', 'Tónica Zero', null, 'lib/img/royal-bliss.jpg', 'Cola', 0),
  ('Nestea', 'Refrescos y zumos', 'Nestea', 'Té', null, 'lib/img/fuze-tea.png', 'Nestea', 106),
  ('Nestea Limón', 'Refrescos y zumos', 'Nestea', 'Limón', null, 'lib/img/fuze-tea.png', 'Nestea', 48),
  ('Nestea Maracuyá', 'Refrescos y zumos', 'Nestea', 'Maracuyá', null, 'lib/img/fuze-tea.png', 'Nestea', 36),
  ('Nestea Melocotón', 'Refrescos y zumos', 'Nestea', 'Melocotón', null, 'lib/img/fuze-tea.png', 'Nestea', 20),
  ('Aquarius', 'Refrescos y zumos', 'Aquarius', 'Naranja', null, 'lib/img/aquarius.png', 'Nestea', 77),
  ('Aquarius Limón', 'Refrescos y zumos', 'Aquarius', 'Limón', null, 'lib/img/aquarius.png', 'Nestea', 24),
  ('Aquarius Piña', 'Refrescos y zumos', 'Aquarius', 'Piña', null, 'lib/img/aquarius.png', 'Nestea', 57),
  ('Aquarius Melocotón', 'Refrescos y zumos', 'Aquarius', 'Melocotón', null, 'lib/img/aquarius.png', 'Nestea', 18),
  ('Zumo', 'Refrescos y zumos', 'Zumo', 'Piña', null, null, 'Cola', 28),
  ('Zumo Melocotón', 'Refrescos y zumos', 'Zumo', 'Melocotón', null, null, 'Cola', 12),
  ('Zumo Naranja', 'Refrescos y zumos', 'Zumo', 'Naranja', null, null, 'Cola', 48),
  ('Fanta Naranja', 'Refrescos y zumos', 'Fanta Naranja', null, null, null, 'Cola', 78),
  ('Agua Aquabona', 'Refrescos y zumos', 'Agua Aquabona', null, null, null, 'Agua', 87),
  ('Agua de cristal Vilas', 'Refrescos y zumos', 'Agua de cristal Vilas', null, null, null, 'Agua', 0),
  ('Monster', 'Refrescos y zumos', 'Monster', null, null, null, 'Energética', 0),
  ('Sprite', 'Refrescos y zumos', 'Sprite', null, null, null, 'Cola', 0),
  ('Limón y Nada', 'Refrescos y zumos', 'Limón y Nada', null, null, null, 'Cola', 0);

-- ---------------------------------------------------------------------------
-- Categorías y grupos de variantes
-- ---------------------------------------------------------------------------
insert into public.category (name)
select distinct category from seed_catalog
on conflict (name) do nothing;

insert into public.product_group (category_id, name, image)
select c.id, s.grp, max(s.group_image)
from seed_catalog s
join public.category c on c.name = s.category
group by c.id, s.grp
on conflict (category_id, name) do nothing;

insert into public.subcategory (group_id, name)
select g.id, s.subcategory
from (
  select distinct category, grp, subcategory
  from seed_catalog
  where subcategory is not null
) s
join public.category c on c.name = s.category
join public.product_group g on g.category_id = c.id and g.name = s.grp
on conflict (group_id, name) do nothing;

-- ---------------------------------------------------------------------------
-- Productos con su stock inicial
-- ---------------------------------------------------------------------------
insert into public.product
  (name, box_id, group_id, subcategory_id, image, unit_in_stock)
select s.name, b.id, g.id, sc.id, s.image, s.units
from seed_catalog s
join public.box_type b on b.type = s.box
join public.category c on c.name = s.category
join public.product_group g on g.category_id = c.id and g.name = s.grp
left join public.subcategory sc
  on sc.group_id = g.id and sc.name = s.subcategory
where not exists (
  select 1
  from public.product p
  where p.group_id = g.id
    and p.name = s.name
    and p.deleted_at is null
);

drop table if exists seed_catalog;

commit;

-- Resumen de lo que ha quedado en el catálogo.
select c.name as categoria,
       count(*) as productos,
       sum(p.unit_in_stock) as unidades
from public.product p
join public.product_group g on g.id = p.group_id
join public.category c on c.id = g.category_id
where p.deleted_at is null
group by c.name
order by c.name;
