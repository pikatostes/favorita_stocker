import 'db.dart';
import 'seed.dart';

/// Inserta el catálogo inicial una sola vez (si la tabla `product` está vacía).
///
/// La normalización del catálogo (categorías, grupos, subcategorías y cajas) la
/// hace [Db.seedCatalog].
Future<void> initializeSeedData() => Db.i.seedCatalog(initialProducts);
