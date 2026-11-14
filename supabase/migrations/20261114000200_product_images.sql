-- ============================================================================
-- 0010 — Imágenes de producto
--
-- Repasa el catálogo y asigna a cada producto sin imagen propia el asset que
-- le corresponde en `lib/img/`. No toca los productos que ya tienen imagen
-- (desde Admin → Productos o migraciones anteriores) ni las imágenes de grupo.
--
-- Notas:
--   · Las variantes nuevas de Coca-Cola Zero y Bliss usan su propia imagen;
--     antes solo heredaban la del grupo. El resto de variantes sin imagen
--     específica (Cruzcampo, Nestea, Aquarius, Coca-Cola normal/light...) sigue
--     mostrando la imagen del grupo.
--   · `berry.avif` se ha convertido a `berry.webp` porque `Image.asset` no
--     decodifica AVIF en todas las plataformas (Windows no lo soporta de serie).
--   · `coca-cola-zero.svg` se ha rasterizado a `coca-cola-zero.png`: Flutter no
--     pinta SVG con `Image.asset` sin añadir `flutter_svg`.
--   · Sprite se queda sin imagen: no hay ningún asset para él en `lib/img/`.
--   · Quedan sin usar `minute-maid.webp` y `maracuya.png` (no hay producto al
--     que correspondan con claridad) y `desperados.jpg` (se usa el PNG nuevo).
--     `coca-cola-zero.svg` y `berry.avif` se conservan como originales.
--
-- Idempotente: solo rellena imágenes vacías, así que se puede repetir sin
-- pisar cambios hechos desde Admin → Productos.
-- ============================================================================

begin;

update public.product p
   set image = v.image
from (values
  -- Cervezas y similares
  ('Cervezas y similares', 'Heineken', 'Heineken',
   'lib/img/heineken.png'),
  ('Cervezas y similares', 'Heineken', 'Heineken 0,0',
   'lib/img/heineken00.png'),
  ('Cervezas y similares', 'Otros', 'Sol',
   'lib/img/sol.png'),
  ('Cervezas y similares', 'Otros', 'Desperados',
   'lib/img/desperados.png'),
  ('Cervezas y similares', 'Otros', 'Ladrón de manzanas',
   'lib/img/ladron-manzanas.png'),
  ('Cervezas y similares', 'Otros', 'Paulaner',
   'lib/img/paulaner.png'),
  ('Cervezas y similares', 'Otros', 'Águila sin filtrar',
   'lib/img/aguila.png'),
  ('Cervezas y similares', 'Otros', 'Guinness',
   'lib/img/guinness.jpg'),

  -- Refrescos y zumos
  ('Refrescos y zumos', 'Coca-Cola', 'Coca-Cola Zero',
   'lib/img/coca-cola-zero.png'),
  ('Refrescos y zumos', 'Coca-Cola', 'Coca-Cola Zero Zero',
   'lib/img/coca-cola-zero-zero.webp'),
  ('Refrescos y zumos', 'Bliss', 'Bliss Berry',
   'lib/img/berry.webp'),
  ('Refrescos y zumos', 'Bliss', 'Bliss Ginger Ale',
   'lib/img/ginger-ale.webp'),
  ('Refrescos y zumos', 'Bliss', 'Bliss Tónica Zero',
   'lib/img/bliss-zero.webp'),
  ('Refrescos y zumos', 'Zumo', 'Zumo',
   'lib/img/pina.png'),
  ('Refrescos y zumos', 'Zumo', 'Zumo Melocotón',
   'lib/img/melocoton.png'),
  ('Refrescos y zumos', 'Zumo', 'Zumo Naranja',
   'lib/img/orange.png'),
  ('Refrescos y zumos', 'Fanta Naranja', 'Fanta Naranja',
   'lib/img/fanta-naranja.png'),
  ('Refrescos y zumos', 'Agua Aquabona', 'Agua Aquabona',
   'lib/img/agua-gas.jpg'),
  ('Refrescos y zumos', 'Agua de cristal Vilas', 'Agua de cristal Vilas',
   'lib/img/agua-cristal.webp'),
  ('Refrescos y zumos', 'Monster', 'Monster',
   'lib/img/monster.png'),
  ('Refrescos y zumos', 'Limón y Nada', 'Limón y Nada',
   'lib/img/limon.png')
) as v(category, grp, product_name, image)
join public.category c on c.name = v.category
join public.product_group g on g.category_id = c.id and g.name = v.grp
where p.group_id = g.id
  and p.name = v.product_name
  and p.deleted_at is null
  and nullif(btrim(p.image), '') is null;

commit;

-- Comprobación: productos que siguen sin ninguna imagen (ni propia ni de
-- grupo) y, por tanto, ven el placeholder en la app.
select p.id,
       p.name,
       g.name as grupo,
       c.name as categoria
from public.product p
join public.product_group g on g.id = p.group_id
join public.category c on c.id = g.category_id
where p.deleted_at is null
  and nullif(btrim(p.image), '') is null
  and nullif(btrim(g.image), '') is null
order by c.name, g.name, p.name;
