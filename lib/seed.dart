import 'models.dart';
import 'shifts.dart';

const _cola = ['Original', 'Zero', 'Zero Zero', 'Light'];
const _bliss = ['Tónica', 'Tónica Zero', 'Limón', 'Berry', 'Ginger Ale'];
const _nestea = ['Té', 'Limón', 'Maracuyá', 'Melocotón'];
const _aquarius = ['Naranja', 'Limón', 'Piña', 'Melocotón'];
const _zumo = ['Piña', 'Melocotón', 'Naranja'];

/// Imágenes propias de las variantes que no comparten la del grupo.
const _colaImages = {
  'Zero': 'lib/img/coca-cola-zero.png',
  'Zero Zero': 'lib/img/coca-cola-zero-zero.webp',
};
const _blissImages = {
  'Tónica Zero': 'lib/img/bliss-zero.webp',
  'Berry': 'lib/img/berry.webp',
  'Ginger Ale': 'lib/img/ginger-ale.webp',
};
const _zumoImages = {
  'Piña': 'lib/img/pina.png',
  'Melocotón': 'lib/img/melocoton.png',
  'Naranja': 'lib/img/orange.png',
};

const _cajaCola =
    CrateType('Cola', 24, 1, 0.5, 1, 6); // 6 por viaje (dato tuyo)
const _cajaNestea = CrateType('Nestea', 24, 1, 1, 1, 5); // SUPUESTO 5 por viaje
const _cerveza =
    CrateType('Cerveza', 24, 1, 1, 2, 5); // 5 por viaje (dato tuyo)
const _aquabona = CrateType('Agua', 20, 2, 1, 3, 5); // 5 por viaje (dato tuyo)
const _cajaEnergia =
    CrateType('Energética', 24, 2, 1, 4, 5); // SUPUESTO 5 por viaje

/// Cantidades de ejemplo, en unidades sueltas, para que el inventario inicial
/// no aparezca todo a cero. Son datos de demostración y se pueden sustituir
/// por el stock real desde la base de datos.
const Map<String, int> _exampleStock = {
  // Cervezas y similares (cajas de 24).
  'Cruzcampo': 132,
  '1904': 72,
  'Cruzcampo Gran Reserva': 54,
  'Cruzcampo Radler': 24,
  'Heineken': 114,
  'Heineken 0,0': 58,
  'Amstel Tostada 0,0': 29,
  'Sol': 72,
  'Desperados': 36,
  'Ladrón de manzanas': 51,
  'Paulaner': 52,
  'Águila sin filtrar': 32,
  'Guinness': 18,
  'Alcázar': 24,
  // Refrescos y zumos (cajas de 24, salvo el agua).
  'Coca-Cola': 156,
  'Coca-Cola Zero': 120,
  'Coca-Cola Zero Zero': 55,
  'Coca-Cola Light': 44,
  'Bliss': 76,
  'Bliss Limón': 24,
  'Bliss Berry': 15,
  'Bliss Ginger Ale': 56,
  'Nestea': 106,
  'Nestea Limón': 48,
  'Nestea Maracuyá': 36,
  'Nestea Melocotón': 20,
  'Aquarius': 77,
  'Aquarius Limón': 24,
  'Aquarius Piña': 57,
  'Aquarius Melocotón': 18,
  'Zumo': 28,
  'Zumo Melocotón': 12,
  'Zumo Naranja': 48,
  'Fanta Naranja': 78,
  'Agua Aquabona': 87,
};

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
  String? groupImage,
}) {
  final groupName = group ?? name;
  return Product(
    name: name,
    category: cat,
    groupName: groupName,
    subcategory: subcategory,
    image: image,
    groupImage: groupImage ?? kGroupImages[groupName],
    box: CrateType(
      crate ?? b.name,
      b.units,
      size ?? b.size,
      height ?? b.height,
      b.format,
      b.trip,
      width: b.width,
    ),
    unitInStock: _exampleStock[name] ?? 0,
  );
}

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
  _p('Cruzcampo Especial Sin Gluten', _cervezas, _cerveza,
      group: 'Cruzcampo', subcategory: 'Especial Sin Gluten'),
  _p('Heineken', _cervezas, _cerveza,
      group: 'Heineken', subcategory: 'Normal', image: 'lib/img/heineken.png'),
  _p('Heineken 0,0', _cervezas, _cerveza,
      group: 'Heineken', subcategory: '0,0', image: 'lib/img/heineken00.png'),
  _otros('Amstel Tostada 0,0', image: 'lib/img/amstel00tostada.jpg'),
  _otros('Sol', image: 'lib/img/sol.png'),
  _otros('Desperados', image: 'lib/img/desperados.png'),
  _otros('Ladrón de manzanas', image: 'lib/img/ladron-manzanas.png'),
  _otros('Paulaner',
      image: 'lib/img/paulaner.png', size: 2, crate: 'Cerveza grande'),
  _otros('Águila sin filtrar',
      image: 'lib/img/aguila.png', size: 2, crate: 'Cerveza grande'),
  _otros('Guinness', image: 'lib/img/guinness.jpg'),
  _otros('Alcázar', image: 'lib/img/alcazar.png'),

  // Refrescos y zumos
  ..._cola.map((subcategoria) => _p(
        subcategoria == 'Original' ? 'Coca-Cola' : 'Coca-Cola $subcategoria',
        _refrescos,
        _cajaCola,
        group: 'Coca-Cola',
        subcategory: subcategoria,
        image: _colaImages[subcategoria],
      )),

  ..._bliss.map((subcategoria) => _p(
        subcategoria == 'Tónica' ? 'Bliss' : 'Bliss $subcategoria',
        _refrescos,
        _cajaCola,
        group: 'Bliss',
        subcategory: subcategoria,
        image: _blissImages[subcategoria],
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
        image: _zumoImages[subcategoria],
      )),

  _p('Fanta Naranja', _refrescos, _cajaCola,
      image: 'lib/img/fanta-naranja.png'), // SUPUESTO
  _p('Sprite', _refrescos, _cajaCola),
  _p('Limón y Nada', _refrescos, _cajaCola, image: 'lib/img/limon.png'),
  _p('Monster', _refrescos, _cajaEnergia, image: 'lib/img/monster.png'),
  _p('Agua Aquabona', _refrescos, _aquabona, image: 'lib/img/agua-gas.jpg'),
  _p('Agua de cristal Vilas', _refrescos, _aquabona,
      image: 'lib/img/agua-cristal.webp'),
];

/// Puestos y plantas iniciales del local.
///
/// El catálogo de puestos es fijo (`camarero` y `manteni`) y las plantas son
/// `planta_baja`, `karaoke` y `terraza`. Cada usuario guarda su planta habitual
/// y su puesto habitual por separado.
const List<JobPosition> initialPositions = JobPosition.values;

/// Usuarios iniciales: nombre, apellidos, email, planta habitual, puesto
/// habitual ([JobPosition]) y rol de acceso.
///
/// Las cuentas se crean con la contraseña temporal «favorita». Alejandro es el
/// único administrador inicial; el resto son empleados. Todos los datos se
/// pueden editar desde la pestaña Usuarios.
const List<
    ({
      String name,
      String surname,
      String email,
      Floor floor,
      JobPosition jobPosition,
      UserRole role,
    })> initialUsers = [
  (
    name: 'Carmen',
    surname: '',
    email: 'carmen@favorita.local',
    floor: Floor.plantaBaja,
    jobPosition: JobPosition.camarero,
    role: UserRole.employee,
  ),
  (
    name: 'Lucía',
    surname: '',
    email: 'lucia@favorita.local',
    floor: Floor.plantaBaja,
    jobPosition: JobPosition.camarero,
    role: UserRole.employee,
  ),
  (
    name: 'María',
    surname: 'Moreno',
    email: 'maria.moreno@favorita.local',
    floor: Floor.plantaBaja,
    jobPosition: JobPosition.camarero,
    role: UserRole.employee,
  ),
  (
    name: 'María',
    surname: 'Hidalgo',
    email: 'maria.hidalgo@favorita.local',
    floor: Floor.plantaBaja,
    jobPosition: JobPosition.camarero,
    role: UserRole.employee,
  ),
  (
    name: 'Elena',
    surname: '',
    email: 'elena@favorita.local',
    floor: Floor.plantaBaja,
    jobPosition: JobPosition.camarero,
    role: UserRole.employee,
  ),
  (
    name: 'Jesús',
    surname: '',
    email: 'jesus@favorita.local',
    floor: Floor.plantaBaja,
    jobPosition: JobPosition.camarero,
    role: UserRole.employee,
  ),
  (
    name: 'Alejandro',
    surname: '',
    email: 'alejandro@favorita.local',
    floor: Floor.plantaBaja,
    jobPosition: JobPosition.manteni,
    role: UserRole.admin,
  ),
  (
    name: 'Alfonso',
    surname: '',
    email: 'alfonso@favorita.local',
    floor: Floor.terraza,
    jobPosition: JobPosition.camarero,
    role: UserRole.employee,
  ),
  (
    name: 'Antonio',
    surname: '',
    email: 'antonio@favorita.local',
    floor: Floor.terraza,
    jobPosition: JobPosition.camarero,
    role: UserRole.employee,
  ),
  (
    name: 'Juanma',
    surname: '',
    email: 'juanma@favorita.local',
    floor: Floor.plantaBaja,
    jobPosition: JobPosition.camarero,
    role: UserRole.employee,
  ),
];
