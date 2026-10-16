import 'models.dart';

const _cola = ['Original', 'Zero', 'Zero Zero', 'Light'];
const _bliss = ['Tónica', 'Limón', 'Berry', 'Ginger Ale'];
const _nestea = ['Té', 'Limón', 'Maracuyá', 'Melocotón'];
const _aquarius = ['Naranja', 'Limón', 'Piña', 'Melocotón'];
const _zumo = ['Piña', 'Melocotón', 'Naranja'];

const _cajaCola =
    CrateType('Cola', 24, 1, 0.5, 1, 6); // 6 por viaje (dato tuyo)
const _cajaNestea = CrateType('Nestea', 24, 1, 1, 1, 5); // SUPUESTO 5 por viaje
const _cerveza =
    CrateType('Cerveza', 24, 1, 1, 2, 5); // 5 por viaje (dato tuyo)
const _aquabona = CrateType('Agua', 20, 2, 1, 3, 5); // 5 por viaje (dato tuyo)

/// Crea un producto de la semilla. Si no se indica grupo, se usa el propio
/// nombre del producto: el grupo es obligatorio en la BD.
Product _p(
  String name,
  String cat,
  CrateType b, {
  double? size,
  double? height,
  String? crate,
  String? group,
  String? subcategory,
  String? image,
}) =>
    Product(
      name: name,
      category: cat,
      groupName: group ?? name,
      subcategory: subcategory,
      image: image,
      box: CrateType(
        crate ?? b.name,
        b.units,
        size ?? b.size,
        height ?? b.height,
        b.format,
        b.trip,
        width: b.width,
      ),
    );

/// Cerveza del grupo de variantes "Otros": su nombre es también su subcategoría.
Product _otros(
  String name, {
  String? image,
  double? size,
  String? crate,
}) =>
    _p(
      name,
      _cervezas,
      _cerveza,
      group: 'Otros',
      subcategory: name,
      image: image,
      size: size,
      crate: crate,
    );

const _cervezas = 'Cervezas y similares';
const _refrescos = 'Refrescos y zumos';

/// Productos iniciales. Los marcados con "SUPUESTO" no tenían tipo de caja
/// indicado: edítalos en la pestaña Productos si no es el correcto.
final List<Product> initialProducts = [
  // Cervezas y similares. Grupo de variantes: Cruzcampo, Heineken y Otros
  // (este último reúne al resto de cervezas).
  _p(
    'Cruzcampo',
    _cervezas,
    _cerveza,
    group: 'Cruzcampo',
    subcategory: 'Pilsen',
    image: 'lib/img/cruzcampo.jfif',
  ),
  _p('1904', _cervezas, _cerveza,
      group: 'Cruzcampo', subcategory: '1904', image: 'lib/img/1904.png'),
  _p('Cruzcampo Gran Reserva', _cervezas, _cerveza,
      group: 'Cruzcampo', subcategory: 'Gran Reserva'),
  _p('Cruzcampo Radler', _cervezas, _cerveza,
      group: 'Cruzcampo', subcategory: 'Radler'),
  _p('Heineken', _cervezas, _cerveza,
      group: 'Heineken', subcategory: 'Normal'),
  _p('Heineken 0,0', _cervezas, _cerveza,
      group: 'Heineken', subcategory: '0,0'),
  _otros('Amstel Tostada 0,0', image: 'lib/img/amstel00tostada.jpg'),
  _otros('Sol'),
  _otros('Desperados'),
  _otros('Ladrón de manzanas'),
  _otros('Paulaner', size: 2, crate: 'Cerveza grande'),
  _otros('Águila sin filtrar', size: 2, crate: 'Cerveza grande'),
  _otros('Guinness'),
  _otros('Alcázar', image: 'lib/img/alcazar.png'),

  // Refrescos y zumos
  ..._cola.map((subcategoria) => _p(
        subcategoria == 'Original' ? 'Coca-Cola' : 'Coca-Cola $subcategoria',
        _refrescos,
        _cajaCola,
        group: 'Coca-Cola',
        subcategory: subcategoria,
      )),

  ..._bliss.map((subcategoria) => _p(
        subcategoria == 'Tónica' ? 'Bliss' : 'Bliss $subcategoria',
        _refrescos,
        _cajaCola,
        group: 'Bliss',
        subcategory: subcategoria,
      )),

  ..._nestea.map((subcategoria) => _p(
        subcategoria == 'Té' ? 'Nestea' : 'Nestea $subcategoria',
        _refrescos,
        _cajaNestea,
        group: 'Nestea',
        subcategory: subcategoria,
      )),

  ..._aquarius.map((subcategoria) => _p(
        subcategoria == 'Naranja' ? 'Aquarius' : 'Aquarius $subcategoria',
        _refrescos,
        _cajaNestea,
        group: 'Aquarius',
        subcategory: subcategoria,
      )),

  ..._zumo.map((subcategoria) => _p(
        subcategoria == 'Piña' ? 'Zumo' : 'Zumo $subcategoria',
        _refrescos,
        _cajaCola,
        group: 'Zumo',
        subcategory: subcategoria,
      )),

  _p('Fanta Naranja', _refrescos, _cajaCola), // SUPUESTO
  _p('Agua Aquabona', _refrescos, _aquabona),
];
