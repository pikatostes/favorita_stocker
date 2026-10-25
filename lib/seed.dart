import 'models.dart';
import 'shifts.dart';

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
  _p('Heineken', _cervezas, _cerveza, group: 'Heineken', subcategory: 'Normal'),
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

/// Puestos iniciales del local. El nombre es único: la planta y la nota se
/// guardan en el propio puesto.
///
/// Se declaran como constantes para que [initialUsers] guarde una referencia al
/// puesto de esta lista y no un nombre suelto.
const _camarero = JobRole(name: 'camarero', floor: Floor.plantaBaja);
const _manteni = JobRole(name: 'manteni', floor: Floor.plantaBaja);
const _camareroKaraoke = JobRole(name: 'camareroo', floor: Floor.karaoke);
const _bandeja = JobRole(name: 'bandeja', floor: Floor.terraza);
const _camareroTerraza = JobRole(name: 'camarerooo', floor: Floor.terraza);

const List<JobRole> initialRoles = [
  _camarero,
  _manteni,
  _camareroKaraoke,
  _bandeja,
  _camareroTerraza,
];

/// Usuarios iniciales: nombre, apellidos, email, puesto habitual ([JobRole]) y
/// rol de acceso.
///
/// Las cuentas se crean con la contraseña temporal «favorita» y el puesto
/// «camarero». Alejandro es el único administrador inicial; el resto son
/// empleados. Todos los datos se pueden editar desde la pestaña Usuarios.
const List<
    ({
      String name,
      String surname,
      String email,
      JobRole jobRole,
      UserRole role,
    })> initialUsers = [
  (
    name: 'Carmen',
    surname: '',
    email: 'carmen@favorita.local',
    jobRole: _camarero,
    role: UserRole.employee,
  ),
  (
    name: 'Lucía',
    surname: '',
    email: 'lucia@favorita.local',
    jobRole: _camarero,
    role: UserRole.employee,
  ),
  (
    name: 'María',
    surname: 'Moreno',
    email: 'maria.moreno@favorita.local',
    jobRole: _camarero,
    role: UserRole.employee,
  ),
  (
    name: 'María',
    surname: 'Hidalgo',
    email: 'maria.hidalgo@favorita.local',
    jobRole: _camarero,
    role: UserRole.employee,
  ),
  (
    name: 'Elena',
    surname: '',
    email: 'elena@favorita.local',
    jobRole: _camarero,
    role: UserRole.employee,
  ),
  (
    name: 'Jesús',
    surname: '',
    email: 'jesus@favorita.local',
    jobRole: _camarero,
    role: UserRole.employee,
  ),
  (
    name: 'Alejandro',
    surname: '',
    email: 'alejandro@favorita.local',
    jobRole: _manteni,
    role: UserRole.admin,
  ),
  (
    name: 'Alfonso',
    surname: '',
    email: 'alfonso@favorita.local',
    jobRole: _bandeja,
    role: UserRole.employee,
  ),
  (
    name: 'Antonio',
    surname: '',
    email: 'antonio@favorita.local',
    jobRole: _camareroTerraza,
    role: UserRole.employee,
  ),
  (
    name: 'Juanma',
    surname: '',
    email: 'juanma@favorita.local',
    jobRole: _camarero,
    role: UserRole.employee,
  ),
];
