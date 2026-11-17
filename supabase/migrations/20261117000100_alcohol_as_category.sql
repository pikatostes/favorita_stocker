-- ============================================================================
-- 0015 — «Alcohol» como categoría, tipos como grupos y marcas como
--        subcategorías
--
-- Corrige la jerarquía que dejó la 0014. El modelo bueno es:
--
--   categoría    = Alcohol
--   grupo        = tipo de bebida (Ron, Whisky, Ginebra, Vodka, Licor…)
--   subcategoría = marca (Havana Club, Barceló, Brugal, Johnnie Walker…)
--   producto     = botella concreta
--
-- Funciona en los dos escenarios posibles:
--   * si la 0014 ya se aplicó, mueve sus grupos (marcas) a subcategorías y
--     convierte los tipos en grupos dentro de «Alcohol»;
--   * si no se aplicó, crea directamente la estructura final y siembra las
--     marcas como subcategorías.
--
-- Ninguna botella se crea aquí: el stock se da de alta desde Inventario.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) Categoría única «Alcohol»
-- ---------------------------------------------------------------------------

insert into public.category (name)
values ('Alcohol')
on conflict (name) do nothing;

-- ---------------------------------------------------------------------------
-- 2) Grupos: tipos de bebida dentro de «Alcohol»
-- ---------------------------------------------------------------------------

insert into public.product_group (category_id, name)
select c.id, t.tipo
from (
  values ('Ron'), ('Whisky'), ('Ginebra'), ('Vodka'), ('Licor'), ('Tequila'),
         ('Brandy')
) as t(tipo)
cross join public.category c
where c.name = 'Alcohol'
on conflict (category_id, name) do nothing;

-- ---------------------------------------------------------------------------
-- 3) Subcategorías: marcas habituales bajo su tipo
-- ---------------------------------------------------------------------------

insert into public.subcategory (group_id, name)
select g.id, m.marca
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
join public.category c on c.name = 'Alcohol'
join public.product_group g on g.category_id = c.id and g.name = m.tipo
on conflict (group_id, name) do nothing;

-- ---------------------------------------------------------------------------
-- 4) Si la 0014 estaba aplicada: cada marca era un grupo de la categoría del
--    tipo. Se convierte en subcategoría del grupo del tipo y se mueven sus
--    productos. Se conservan también marcas creadas a mano.
-- ---------------------------------------------------------------------------

insert into public.subcategory (group_id, name)
select tg.id, g.name
from public.product_group g
join public.category c on c.id = g.category_id
join public.category ca on ca.name = 'Alcohol'
join public.product_group tg on tg.category_id = ca.id and tg.name = c.name
where c.name in ('Ron', 'Whisky', 'Ginebra', 'Vodka', 'Licor', 'Tequila',
                 'Brandy')
  and tg.id <> g.id
on conflict (group_id, name) do nothing;

update public.product p
set group_id = tg.id,
    subcategory_id = s.id
from public.product_group g
join public.category c on c.id = g.category_id
join public.category ca on ca.name = 'Alcohol'
join public.product_group tg on tg.category_id = ca.id and tg.name = c.name
join public.subcategory s on s.group_id = tg.id and s.name = g.name
where p.group_id = g.id
  and c.name in ('Ron', 'Whisky', 'Ginebra', 'Vodka', 'Licor', 'Tequila',
                 'Brandy');

-- ---------------------------------------------------------------------------
-- 5) Si la 0013 estaba aplicada: había marcas creadas como grupos de
--    «Alcohol». Se reubican en su tipo según la lista de marcas conocidas.
-- ---------------------------------------------------------------------------

insert into public.subcategory (group_id, name)
select tg.id, m.marca
from (
  values
    ('Ron', 'Havana Club'), ('Ron', 'Cacique'), ('Ron', 'Bacardí'),
    ('Ron', 'Brugal'), ('Ron', 'Barceló'), ('Ron', 'Santa Teresa'),
    ('Ron', 'Pampero'), ('Ron', 'Diplomático'),
    ('Whisky', 'Johnnie Walker'), ('Whisky', 'Dewar''s'),
    ('Whisky', 'Ballantine''s'), ('Whisky', 'Chivas Regal'), ('Whisky', 'J&B'),
    ('Whisky', 'Jameson'), ('Whisky', 'Jack Daniel''s'), ('Whisky', 'DYC'),
    ('Whisky', 'Cardhu'),
    ('Ginebra', 'Beefeater'), ('Ginebra', 'Tanqueray'), ('Ginebra', 'Gordon''s'),
    ('Ginebra', 'Larios'), ('Ginebra', 'Bombay Sapphire'),
    ('Ginebra', 'Puerto de Indias'), ('Ginebra', 'Hendrick''s'),
    ('Ginebra', 'Seagram''s'),
    ('Vodka', 'Absolut'), ('Vodka', 'Smirnoff'), ('Vodka', 'Grey Goose'),
    ('Vodka', 'Belvedere'), ('Vodka', 'Ciroc'), ('Vodka', 'Ketel One'),
    ('Vodka', 'Wyborowa'),
    ('Licor', 'Licor 43'), ('Licor', 'Baileys'), ('Licor', 'Jägermeister'),
    ('Licor', 'Cointreau'), ('Licor', 'Kahlúa'),
    ('Licor', 'Amaretto Disaronno'), ('Licor', 'Ruavieja'),
    ('Tequila', 'José Cuervo'), ('Tequila', 'Camino Real'),
    ('Tequila', 'Sauza'), ('Tequila', 'Patrón'),
    ('Brandy', 'Soberano'), ('Brandy', 'Torres 10'), ('Brandy', 'Carlos I'),
    ('Brandy', 'Fundador'), ('Brandy', 'Terry')
) as m(tipo, marca)
join public.category ca on ca.name = 'Alcohol'
join public.product_group tg on tg.category_id = ca.id and tg.name = m.tipo
on conflict (group_id, name) do nothing;

update public.product p
set group_id = tg.id,
    subcategory_id = s.id
from public.product_group g
join public.category ca on ca.id = g.category_id and ca.name = 'Alcohol'
join (
  values
    ('Ron', 'Havana Club'), ('Ron', 'Cacique'), ('Ron', 'Bacardí'),
    ('Ron', 'Brugal'), ('Ron', 'Barceló'), ('Ron', 'Santa Teresa'),
    ('Ron', 'Pampero'), ('Ron', 'Diplomático'),
    ('Whisky', 'Johnnie Walker'), ('Whisky', 'Dewar''s'),
    ('Whisky', 'Ballantine''s'), ('Whisky', 'Chivas Regal'), ('Whisky', 'J&B'),
    ('Whisky', 'Jameson'), ('Whisky', 'Jack Daniel''s'), ('Whisky', 'DYC'),
    ('Whisky', 'Cardhu'),
    ('Ginebra', 'Beefeater'), ('Ginebra', 'Tanqueray'), ('Ginebra', 'Gordon''s'),
    ('Ginebra', 'Larios'), ('Ginebra', 'Bombay Sapphire'),
    ('Ginebra', 'Puerto de Indias'), ('Ginebra', 'Hendrick''s'),
    ('Ginebra', 'Seagram''s'),
    ('Vodka', 'Absolut'), ('Vodka', 'Smirnoff'), ('Vodka', 'Grey Goose'),
    ('Vodka', 'Belvedere'), ('Vodka', 'Ciroc'), ('Vodka', 'Ketel One'),
    ('Vodka', 'Wyborowa'),
    ('Licor', 'Licor 43'), ('Licor', 'Baileys'), ('Licor', 'Jägermeister'),
    ('Licor', 'Cointreau'), ('Licor', 'Kahlúa'),
    ('Licor', 'Amaretto Disaronno'), ('Licor', 'Ruavieja'),
    ('Tequila', 'José Cuervo'), ('Tequila', 'Camino Real'),
    ('Tequila', 'Sauza'), ('Tequila', 'Patrón'),
    ('Brandy', 'Soberano'), ('Brandy', 'Torres 10'), ('Brandy', 'Carlos I'),
    ('Brandy', 'Fundador'), ('Brandy', 'Terry')
) as m(tipo, marca) on m.marca = g.name
join public.product_group tg on tg.category_id = ca.id and tg.name = m.tipo
join public.subcategory s on s.group_id = tg.id and s.name = m.marca
where p.group_id = g.id
  and tg.id <> g.id;

-- ---------------------------------------------------------------------------
-- 6) Limpieza del modelo antiguo: subcategorías y grupos huérfanos, y las
--    categorías de tipo que hayan quedado vacías.
-- ---------------------------------------------------------------------------

delete from public.subcategory s
using public.product_group g
join public.category c on c.id = g.category_id
where s.group_id = g.id
  and c.name in ('Ron', 'Whisky', 'Ginebra', 'Vodka', 'Licor', 'Tequila',
                 'Brandy')
  and not exists (select 1 from public.product p where p.subcategory_id = s.id);

delete from public.product_group g
using public.category c
where g.category_id = c.id
  and c.name in ('Ron', 'Whisky', 'Ginebra', 'Vodka', 'Licor', 'Tequila',
                 'Brandy')
  and not exists (select 1 from public.product p where p.group_id = g.id)
  and not exists (select 1 from public.subcategory s where s.group_id = g.id);

-- Marcas que quedaron como grupo suelto dentro de «Alcohol» y ya se movieron.
delete from public.product_group g
using public.category c
where g.category_id = c.id
  and c.name = 'Alcohol'
  and g.name not in ('Ron', 'Whisky', 'Ginebra', 'Vodka', 'Licor', 'Tequila',
                     'Brandy')
  and not exists (select 1 from public.product p where p.group_id = g.id)
  and not exists (select 1 from public.subcategory s where s.group_id = g.id);

delete from public.category c
where c.name in ('Ron', 'Whisky', 'Ginebra', 'Vodka', 'Licor', 'Tequila',
                 'Brandy')
  and not exists (select 1 from public.product_group g where g.category_id = c.id);

-- Comprobación: grupos de «Alcohol» con número de marcas y botellas.
select g.name as tipo,
       count(distinct s.id) as marcas,
       count(p.id) filter (where p.deleted_at is null) as botellas
from public.product_group g
join public.category c on c.id = g.category_id
left join public.subcategory s on s.group_id = g.id
left join public.product p on p.group_id = g.id
where c.name = 'Alcohol'
group by g.name
order by g.name;
