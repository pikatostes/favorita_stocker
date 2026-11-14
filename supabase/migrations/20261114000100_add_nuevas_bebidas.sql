-- ============================================================================
-- 0009 — Alta de cinco bebidas en el catálogo
--
-- Monster, Sprite, Cruzcampo Especial Sin Gluten, Bliss Tónica Zero y
-- Limón y Nada. No existe una tabla plana de productos: cada alta necesita
-- categoría (vía `product_group`), grupo y tipo de caja.
--
-- Decisiones de modelado:
--   · Cruzcampo Especial Sin Gluten entra como variante del grupo `Cruzcampo`
--     (subcategoría «Especial Sin Gluten»), igual que Gran Reserva o Radler.
--   · Bliss Tónica Zero entra como variante del grupo `Bliss`
--     (subcategoría «Tónica Zero»), junto a Tónica, Limón, Berry y Ginger Ale.
--   · Monster, Sprite y Limón y Nada son grupos de un solo producto: se
--     guardan con un grupo propio y sin subcategoría para que
--     `buildProductEntries` los muestre sueltos.
--   · Cervezas y refrescos de 33 cl reutilizan las cajas `Cerveza` y `Cola`
--     para no duplicar tipos. Monster (500 ml) no cabe en `Cola` (altura 0.5,
--     pensada para el botellín de 33 cl), así que se crea el tipo `Energética`
--     con formato 4 para que el planificador no la mezcle con las colas. Estos
--     valores son una suposición; se ajustan en Admin → Productos, teniendo en
--     cuenta que el tipo de caja es compartido por todos sus productos.
--   · El stock arranca en 0; el stock real se fija desde Admin → Inventario.
--
-- No usa tablas temporales: el editor SQL de Supabase no garantiza que una
-- tabla `temp` sobreviva entre sentencias del mismo script.
--
-- Idempotente: se puede ejecutar varias veces sin duplicar nada.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- Tipos de caja
--
-- En una base creada solo con las migraciones (sin seed_catalog.sql) todavía
-- no existen, así que se crean con los mismos valores que la semilla.
-- ---------------------------------------------------------------------------
insert into public.box_type
  (type, units_per_box, size, height, width, format, trip_capacity)
values
  ('Cerveza', 24, 1, 1, 1, 2, 5),
  ('Cola', 24, 1, 0.5, 1, 1, 6),
  ('Energética', 24, 2, 1, 1, 4, 5)
on conflict (type) do nothing;

insert into public.category (name)
values
  ('Cervezas y similares'),
  ('Refrescos y zumos')
on conflict (name) do nothing;

-- ---------------------------------------------------------------------------
-- Grupos de variantes
-- ---------------------------------------------------------------------------
insert into public.product_group (category_id, name)
select c.id, v.grp
from (values
  ('Cervezas y similares', 'Cruzcampo'),
  ('Refrescos y zumos', 'Monster'),
  ('Refrescos y zumos', 'Sprite'),
  ('Refrescos y zumos', 'Bliss'),
  ('Refrescos y zumos', 'Limón y Nada')
) as v(category, grp)
join public.category c on c.name = v.category
on conflict (category_id, name) do nothing;

-- ---------------------------------------------------------------------------
-- Variantes (solo los productos que comparten grupo)
-- ---------------------------------------------------------------------------
insert into public.subcategory (group_id, name)
select g.id, v.subcategory
from (values
  ('Cervezas y similares', 'Cruzcampo', 'Especial Sin Gluten'),
  ('Refrescos y zumos', 'Bliss', 'Tónica Zero')
) as v(category, grp, subcategory)
join public.category c on c.name = v.category
join public.product_group g on g.category_id = c.id and g.name = v.grp
on conflict (group_id, name) do nothing;

-- ---------------------------------------------------------------------------
-- Productos con su stock inicial
-- ---------------------------------------------------------------------------
insert into public.product
  (name, box_id, group_id, subcategory_id, image, unit_in_stock)
select v.name, b.id, g.id, sc.id, null, 0
from (values
  ('Cruzcampo Especial Sin Gluten', 'Cervezas y similares', 'Cruzcampo',
   'Especial Sin Gluten', 'Cerveza'),
  ('Monster', 'Refrescos y zumos', 'Monster', null, 'Energética'),
  ('Sprite', 'Refrescos y zumos', 'Sprite', null, 'Cola'),
  ('Bliss Tónica Zero', 'Refrescos y zumos', 'Bliss', 'Tónica Zero', 'Cola'),
  ('Limón y Nada', 'Refrescos y zumos', 'Limón y Nada', null, 'Cola')
) as v(name, category, grp, subcategory, box)
join public.box_type b on b.type = v.box
join public.category c on c.name = v.category
join public.product_group g on g.category_id = c.id and g.name = v.grp
left join public.subcategory sc
  on sc.group_id = g.id and sc.name = v.subcategory
where not exists (
  select 1
  from public.product p
  where p.group_id = g.id
    and p.name = v.name
    and p.deleted_at is null
);

commit;

-- Comprobación rápida en el SQL Editor.
select p.id,
       p.name,
       c.name as categoria,
       g.name as grupo,
       sc.name as variante,
       b.type as caja,
       b.units_per_box,
       p.unit_in_stock
from public.product p
join public.product_group g on g.id = p.group_id
join public.category c on c.id = g.category_id
join public.box_type b on b.id = p.box_id
left join public.subcategory sc on sc.id = p.subcategory_id
where p.name in (
  'Cruzcampo Especial Sin Gluten',
  'Monster',
  'Sprite',
  'Bliss Tónica Zero',
  'Limón y Nada'
)
  and p.deleted_at is null
order by c.name, p.name;
