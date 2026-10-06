import 'models.dart';

/// Tipos de caja: nombre, unidades, tamaño, altura, formato, cajas por viaje.
class _Box {
  final String name;
  final int units, format, trip;
  final double size, height;
  const _Box(
      this.name, this.units, this.size, this.height, this.format, this.trip);
}

const _cola = ['Original', 'Zero', 'Zero Zero', 'Light'];
const _bliss = ['Tónica', 'Limón', 'Berry', 'Ginger Ale'];
const _nestea = ['Té', 'Limón', 'Maracuyá', 'Melocotón'];
const _aquarius = ['Naranja', 'Limón', 'Piña', 'Melocotón'];
const _zumo = ['Piña', 'Melocotón', 'Naranja'];

const _cajaCola = _Box('Cola', 24, 1, 0.5, 1, 6); // 6 por viaje (dato tuyo)
const _cajaNestea = _Box('Nestea', 24, 1, 1, 1, 5); // SUPUESTO 5 por viaje
const _cerveza = _Box('Cerveza', 24, 1, 1, 2, 5); // 5 por viaje (dato tuyo)
const _aquabona = _Box('Agua', 20, 2, 1, 3, 5); // 5 por viaje (dato tuyo)

Product _p(String name, String cat, _Box b,
        {double? size,
        double? height,
        String? crate,
        String? group,
        String? subcategory}) =>
    Product(
      name: name,
      category: cat,
      groupName: group,
      subcategory: subcategory,
      unitsPerBox: b.units,
      size: size ?? b.size,
      height: height ?? b.height,
      format: b.format,
      crateName: crate ?? b.name,
      tripCapacity: b.trip,
    );

const _cervezas = 'Cervezas y similares';
const _refrescos = 'Refrescos y zumos';

/// Productos iniciales. Los marcados con "SUPUESTO" no tenían tipo de caja
/// indicado: edítalos en la pestaña Productos si no es el correcto.
final List<Product> initialProducts = [
  // Cervezas y similares (SUPUESTO: caja tipo Cruzcampo/Heineken)
  _p('Cruzcampo', _cervezas, _cerveza),
  _p('Heineken', _cervezas, _cerveza),
  _p('1904', _cervezas, _cerveza),
  _p('Heineken 0,0', _cervezas, _cerveza),
  _p('Amstel Tostada 0,0', _cervezas, _cerveza),
  _p('Sol', _cervezas, _cerveza),
  _p('Desperados', _cervezas, _cerveza),
  _p('Ladrón de manzanas', _cervezas, _cerveza),
  _p('Cruzcampo Gran Reserva', _cervezas, _cerveza),
  _p('Paulaner', _cervezas, _cerveza, size: 2, crate: 'Cerveza grande'),
  _p('Águila sin filtrar', _cervezas, _cerveza,
      size: 2, crate: 'Cerveza grande'),
  _p('Guinness', _cervezas, _cerveza),
  _p('Cruzcampo Radler', _cervezas, _cerveza),
  _p('Alcázar', _cervezas, _cerveza),

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
