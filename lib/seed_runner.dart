import 'db.dart';
import 'seed.dart';

/// Inserta el catálogo inicial una sola vez (si la tabla `product` está vacía).
///
/// La normalización del catálogo (categorías, grupos, subcategorías y cajas) la
/// hace [Db.seedCatalog]. Los puestos y usuarios iniciales se insertan solo si
/// la tabla `users` está vacía.
Future<void> initializeSeedData() async {
  await Db.i.seedCatalog(initialProducts);
  await Db.i.seedStaff(initialRoles, initialUsers);
}
