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

const _cervezas = 'Cervezas y similares';
const _refrescos = 'Refrescos y zumos';

/// Productos iniciales. Los marcados con "SUPUESTO" no tenían tipo de caja
/// indicado: edítalos en la pestaña Productos si no es el correcto.
final List<Product> initialProducts = [
  // Cervezas y similares (SUPUESTO: caja tipo Cruzcampo/Heineken)
  _p(
    'Cruzcampo',
    _cervezas,
    _cerveza,
    image: 'lib/img/cruzcampo.jfif',
  ),
  _p('Heineken', _cervezas, _cerveza),
  _p('1904', _cervezas, _cerveza, image: 'lib/img/1904.png'),
  _p('Heineken 0,0', _cervezas, _cerveza),
  _p('Amstel Tostada 0,0', _cervezas, _cerveza, image: 'lib/img/amstel00tostada.jpg'),
  _p('Sol', _cervezas, _cerveza),
  _p('Desperados', _cervezas, _cerveza),
  _p('Ladrón de manzanas', _cervezas, _cerveza),
  _p('Cruzcampo Gran Reserva', _cervezas, _cerveza),
  _p('Paulaner', _cervezas, _cerveza, size: 2, crate: 'Cerveza grande'),
  _p('Águila sin filtrar', _cervezas, _cerveza,
      size: 2, crate: 'Cerveza grande'),
  _p('Guinness', _cervezas, _cerveza),
  _p('Cruzcampo Radler', _cervezas, _cerveza),
  _p('Alcázar', _cervezas, _cerveza, image: 'lib/img/alcazar.png'),

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
