-- ============================================================================
-- 0014 — Tipos de alcohol como categorías y marcas como grupos
--
-- La migración 0013 dejó una única categoría «Alcohol». El catálogo real
-- distingue dos niveles:
--
--   categoría  = tipo de bebida (Ron, Whisky, Ginebra, Vodka, Licor…)
--   grupo      = marca (Havana Club, Johnnie Walker, Beefeater…)
--   producto   = botella concreta (la subcategoría opcional guarda la variante)
--
-- Así cada tipo de alcohol tiene su propia pestaña en Lista e Inventario, y
-- dentro se agrupan las botellas por marca, igual que las cervezas se agrupan
-- por Cruzcampo/Heineken.
--
-- Se siembran las categorías y las marcas más habituales para que se puedan
-- elegir en Admin → Productos sin escribir SQL. No se crea ninguna botella:
-- el stock se da de alta desde Inventario.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Categorías: tipos de alcohol
-- ---------------------------------------------------------------------------

insert into public.category (name)
values
  ('Ron'),
  ('Whisky'),
  ('Ginebra'),
  ('Vodka'),
  ('Licor'),
  ('Tequila'),
  ('Brandy')
on conflict (name) do nothing;

-- ---------------------------------------------------------------------------
-- Grupos: marcas de cada tipo
-- ---------------------------------------------------------------------------

insert into public.product_group (category_id, name)
select c.id, m.marca
from (
  values
    ('Ron', 'Havana Club'),
    ('Ron', 'Cacique'),
    ('Ron', 'Bacardí'),
    ('Ron', 'Brugal'),
    ('Ron', 'Barceló'),
    ('Ron', 'Santa Teresa'),
    ('Ron', 'Pampero'),
    ('Ron', 'Diplomático'),
    ('Whisky', 'Johnnie Walker'),
    ('Whisky', 'Dewar''s'),
    ('Whisky', 'Ballantine''s'),
    ('Whisky', 'Chivas Regal'),
    ('Whisky', 'J&B'),
    ('Whisky', 'Jameson'),
    ('Whisky', 'Jack Daniel''s'),
    ('Whisky', 'DYC'),
    ('Whisky', 'Cardhu'),
    ('Ginebra', 'Beefeater'),
    ('Ginebra', 'Tanqueray'),
    ('Ginebra', 'Gordon''s'),
    ('Ginebra', 'Larios'),
    ('Ginebra', 'Bombay Sapphire'),
    ('Ginebra', 'Puerto de Indias'),
    ('Ginebra', 'Hendrick''s'),
    ('Ginebra', 'Seagram''s'),
    ('Vodka', 'Absolut'),
    ('Vodka', 'Smirnoff'),
    ('Vodka', 'Grey Goose'),
    ('Vodka', 'Belvedere'),
    ('Vodka', 'Ciroc'),
    ('Vodka', 'Ketel One'),
    ('Vodka', 'Wyborowa'),
    ('Licor', 'Licor 43'),
    ('Licor', 'Baileys'),
    ('Licor', 'Jägermeister'),
    ('Licor', 'Cointreau'),
    ('Licor', 'Kahlúa'),
    ('Licor', 'Amaretto Disaronno'),
    ('Licor', 'Ruavieja'),
    ('Tequila', 'José Cuervo'),
    ('Tequila', 'Camino Real'),
    ('Tequila', 'Sauza'),
    ('Tequila', 'Patrón'),
    ('Brandy', 'Soberano'),
    ('Brandy', 'Torres 10'),
    ('Brandy', 'Carlos I'),
    ('Brandy', 'Fundador'),
    ('Brandy', 'Terry')
) as m(tipo, marca)
join public.category c on c.name = m.tipo
on conflict (category_id, name) do nothing;

-- La categoría genérica de 0013 solo se elimina si nadie ha creado grupos en
-- ella. Si ya tiene marcas, se deja para no perder datos.
delete from public.category c
where c.name = 'Alcohol'
  and not exists (
    select 1 from public.product_group g where g.category_id = c.id
  );

-- Comprobación: tipos de alcohol con sus marcas.
select c.name as tipo,
       count(g.id) as marcas,
       count(p.id) filter (where p.deleted_at is null) as botellas
from public.category c
left join public.product_group g on g.category_id = c.id
left join public.product p on p.group_id = g.id
where c.name in ('Ron', 'Whisky', 'Ginebra', 'Vodka', 'Licor', 'Tequila',
                 'Brandy')
group by c.name
order by c.name;
