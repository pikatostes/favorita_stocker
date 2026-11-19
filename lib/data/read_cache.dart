/// Caché en memoria de lecturas con invalidación por tabla.
///
/// Cada entrada guarda la consulta (en curso o resuelta) y las tablas de las
/// que depende. Al invalidar una tabla solo se descartan las entradas que la
/// usan, de modo que un cambio de incidencias no obliga a recargar el catálogo
/// ni el horario.
///
/// No depende de Flutter ni de Supabase: se puede probar de forma aislada.
class ReadCache {
  final Map<String, _CacheEntry> _entries = {};

  /// Devuelve el resultado cacheado de [key] o ejecuta [load] y lo guarda.
  ///
  /// Dos llamadas concurrentes con la misma clave comparten la misma consulta.
  /// Si [load] falla, la entrada no se conserva para permitir reintentar.
  Future<T> read<T>({
    required String key,
    required Iterable<String> tables,
    required Future<T> Function() load,
  }) {
    final existing = _entries[key];
    if (existing != null) return existing.future.then((value) => value as T);

    final entry = _CacheEntry(Set<String>.unmodifiable(tables), load());
    _entries[key] = entry;
    entry.future.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (identical(_entries[key], entry)) _entries.remove(key);
      },
    );
    return entry.future.then((value) => value as T);
  }

  /// Descarta las entradas que dependan de alguna de [tables].
  ///
  /// Sin tablas se vacía toda la caché, que es la opción segura cuando no se
  /// sabe qué cambió.
  void invalidate(Iterable<String> tables) {
    final changed = Set<String>.unmodifiable(tables);
    if (changed.isEmpty) {
      clear();
      return;
    }
    _entries.removeWhere((_, entry) => entry.tables.any(changed.contains));
  }

  /// Vacía la caché por completo (por ejemplo, al cambiar de sesión).
  void clear() => _entries.clear();
}

/// Entrada de la caché: la consulta y las tablas que la invalidan.
class _CacheEntry {
  final Set<String> tables;
  final Future<Object?> future;

  const _CacheEntry(this.tables, this.future);
}
