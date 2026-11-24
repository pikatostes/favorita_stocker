import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/data/read_cache.dart';

void main() {
  group('ReadCache', () {
    test('reutiliza el resultado de la misma clave', () async {
      var calls = 0;
      Future<List<String>> load() async {
        calls++;
        return ['Ana'];
      }

      final cache = ReadCache();
      final first =
          await cache.read(key: 'users', tables: ['profiles'], load: load);
      final second =
          await cache.read(key: 'users', tables: ['profiles'], load: load);

      expect(first, ['Ana']);
      expect(second, first);
      expect(calls, 1);
    });

    test('comparte la consulta si se pide dos veces a la vez', () async {
      var calls = 0;
      final completer = Completer<int>();
      Future<int> load() {
        calls++;
        return completer.future;
      }

      final cache = ReadCache();
      final first = cache.read(key: 'stock', tables: ['product'], load: load);
      final second = cache.read(key: 'stock', tables: ['product'], load: load);

      completer.complete(42);

      expect(await first, 42);
      expect(await second, 42);
      expect(calls, 1);
    });

    test('una tabla no relacionada no invalida la entrada', () async {
      var calls = 0;
      Future<int> load() async => ++calls;

      final cache = ReadCache();
      await cache.read(key: 'positions', tables: ['job_position'], load: load);
      cache.invalidate(['incident']);

      expect(
        await cache.read(
            key: 'positions', tables: ['job_position'], load: load),
        1,
      );
      expect(calls, 1);
    });

    test('invalidar una tabla dependiente obliga a recargar', () async {
      var calls = 0;
      Future<int> load() async => ++calls;

      final cache = ReadCache();
      await cache.read(key: 'positions', tables: ['job_position'], load: load);
      cache.invalidate(['job_position']);

      expect(
        await cache.read(
            key: 'positions', tables: ['job_position'], load: load),
        2,
      );
      expect(calls, 2);
    });

    test('sin tablas se vacía toda la caché', () async {
      var calls = 0;
      Future<int> load() async => ++calls;

      final cache = ReadCache();
      await cache.read(key: 'a', tables: ['product'], load: load);
      await cache.read(key: 'b', tables: ['shift'], load: load);
      cache.invalidate(const []);

      expect(await cache.read(key: 'a', tables: ['product'], load: load), 3);
      expect(await cache.read(key: 'b', tables: ['shift'], load: load), 4);
    });

    test('un error no se cachea y permite reintentar', () async {
      var calls = 0;
      Future<int> load() async {
        calls++;
        if (calls == 1) throw StateError('fallo temporal');
        return 7;
      }

      final cache = ReadCache();
      await expectLater(
        cache.read(key: 'stock', tables: ['product'], load: load),
        throwsStateError,
      );

      expect(
        await cache.read(key: 'stock', tables: ['product'], load: load),
        7,
      );
      expect(calls, 2);
    });
  });
}
