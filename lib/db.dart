import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';
import 'incidents.dart';
import 'models.dart';
import 'schedule.dart';
import 'shifts.dart';

/// Convierte un error de la capa de datos en un texto para la UI.
///
/// [Db] ya envuelve los errores de PostgREST en [StateError] con un mensaje en
/// español; [ArgumentError] conserva el mensaje de validación.
String describeDbError(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Los datos no son válidos.';
  }
  return error.toString();
}

/// Acceso a Supabase.
///
/// Mantiene la misma API pública que la antigua capa SQLite (`Db.i`), de modo
/// que las pantallas siguen usando `FutureBuilder` y `Db.i.version` sin
/// cambios. Las escrituras transaccionales se delegan a funciones RPC y la
/// lectura usa vistas que reproducen las columnas planas de los modelos.
class Db {
  Db._();
  static final Db i = Db._();

  /// Se incrementa con cada escritura local o evento de Realtime. Las pantallas
  /// escuchan para refrescarse, igual que con SQLite.
  final ValueNotifier<int> version = ValueNotifier(0);
  void _changed() => version.value++;

  SupabaseClient get _client => Supabase.instance.client;
  RealtimeChannel? _channel;

  static const List<String> _watchedTables = [
    'category',
    'box_type',
    'product_group',
    'subcategory',
    'product',
    'night',
    'consumption',
    'special_day',
    'job_role',
    'profiles',
    'shift',
    'incident',
  ];

  /// Se suscribe a los cambios de las tablas que alimentan la UI.
  Future<void> connectRealtime() async {
    if (_channel != null) return;
    final channel = _client.channel('db-changes');
    for (final table in _watchedTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _changed(),
      );
    }
    _channel = channel;
    channel.subscribe();
  }

  Future<void> disconnectRealtime() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await channel.unsubscribe();
  }

  /// Emite `true` cuando Supabase cierra la sesión (token caducado, cuenta
  /// bloqueada, cierre desde otro dispositivo…).
  Stream<bool> get signedOut => _client.auth.onAuthStateChange
      .map((state) => state.event == AuthChangeEvent.signedOut);

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();
  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static String _friendly(Object error) {
    if (error is PostgrestException) {
      if (error.code == '42501') {
        return 'No tienes permisos para esta acción.';
      }
      if (error.code == '23505') {
        return 'Ya existe un registro con esos datos.';
      }
      if (error.code == '23503') {
        return 'El registro está en uso y no se puede borrar.';
      }
      if (error.code == 'PGRST116') {
        return 'No se encontró el registro.';
      }
      return error.message;
    }
    if (error is AuthException) return error.message;
    if (error is StorageException) {
      final message = error.message.toLowerCase();
      if (message.contains('maximum') && message.contains('size')) {
        return 'La imagen es demasiado grande.';
      }
      if (message.contains('mime')) {
        return 'El formato de la imagen no es válido.';
      }
      return error.message;
    }
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map && details['error'] != null) {
        return details['error'].toString();
      }
      return error.toString();
    }
    return error.toString();
  }

  Future<Map<String, dynamic>> _invokeAdmin(Map<String, dynamic> body) async {
    try {
      final response =
          await _client.functions.invoke('admin-users', body: body);
      final data = response.data;
      if (response.status >= 400) {
        final message = data is Map && data['error'] != null
            ? data['error'].toString()
            : 'No se pudo gestionar el usuario.';
        throw StateError(message);
      }
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } on FunctionException catch (error) {
      throw StateError(_friendly(error));
    }
  }

  // ---------------------------------------------------------------------------
  // Productos
  // ---------------------------------------------------------------------------

  /// Productos vivos (o todos, con [includeDeleted]) con su grupo y caja.
  Future<List<Product>> products({bool includeDeleted = false}) async {
    var query = _client.from('product_view').select();
    if (!includeDeleted) {
      query = query.isFilter('deleted_at', null);
    }
    final rows = await query.order('category').order('name');
    return [
      for (final row in rows) Product.fromRow(Map<String, Object?>.from(row)),
    ];
  }

  /// Categorías existentes.
  Future<List<String>> categories() async {
    final rows = await _client.from('category').select('name').order('name');
    return [for (final row in rows) row['name'] as String];
  }

  /// Tipos de caja existentes (tabla `box_type`).
  Future<List<CrateType>> boxTypes() async {
    final rows = await _client.from('box_type').select().order('type');
    return [
      for (final row in rows)
        CrateType(
          row['type'] as String,
          row['units_per_box'] as int,
          (row['size'] as num).toDouble(),
          (row['height'] as num).toDouble(),
          row['format'] as int,
          row['trip_capacity'] as int,
          width: (row['width'] as num).toDouble(),
          id: row['id'] as int,
        ),
    ];
  }

  /// Grupos de variantes (categoría y nombre) existentes en la BD.
  Future<List<({String category, String name})>> productGroups() async {
    final rows = await _client
        .from('product_group_view')
        .select('category, name')
        .order('category')
        .order('name');
    return [
      for (final row in rows)
        (
          category: row['category'] as String,
          name: row['name'] as String,
        ),
    ];
  }

  /// Subcategorías con su categoría y grupo.
  Future<List<({String category, String group, String name})>>
      subcategories() async {
    final rows = await _client
        .from('subcategory_view')
        .select('category, grp, name')
        .order('category')
        .order('grp')
        .order('name');
    return [
      for (final row in rows)
        (
          category: row['category'] as String,
          group: row['grp'] as String,
          name: row['name'] as String,
        ),
    ];
  }

  Map<String, dynamic> _productParams(Product p, String? groupImage) => {
        'p_id': p.id,
        'p_name': p.name.trim(),
        'p_category': p.category.trim(),
        'p_group': p.groupName!.trim(),
        'p_subcategory': p.subcategory?.trim(),
        'p_box': {
          'type': p.box.name.trim(),
          'units': p.box.units,
          'size': p.box.size,
          'height': p.box.height,
          'width': p.box.width,
          'format': p.box.format,
          'trip': p.box.trip,
        },
        'p_image': p.image,
        'p_group_image': groupImage,
        'p_unit_in_stock': p.unitInStock,
      };

  Future<void> addProduct(Product p, {required String? groupImage}) async {
    final validationError = p.validationError;
    if (validationError != null) {
      throw ArgumentError.value(p, 'product', validationError);
    }
    try {
      await _client.rpc('save_product', params: _productParams(p, groupImage));
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  Future<void> updateProduct(Product p, {required String? groupImage}) async {
    if (p.id == null) {
      throw ArgumentError.value(p.id, 'id', 'El producto debe tener un id.');
    }
    final validationError = p.validationError;
    if (validationError != null) {
      throw ArgumentError.value(p, 'product', validationError);
    }
    try {
      await _client.rpc('save_product', params: _productParams(p, groupImage));
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  Future<String?> productGroupImage({
    required String category,
    required String name,
  }) async {
    final row = await _client
        .from('product_group_view')
        .select('image')
        .eq('category', category.trim())
        .eq('name', name.trim())
        .maybeSingle();
    return row == null ? null : row['image'] as String?;
  }

  Future<void> setProductGroupImage({
    required String category,
    required String name,
    required String? image,
  }) async {
    if (category.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError(
          'La categoría y el nombre del grupo son obligatorios.');
    }
    try {
      await _client.rpc('set_group_image', params: {
        'p_category': category.trim(),
        'p_group': name.trim(),
        'p_image': image,
      });
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  /// Borrado lógico: el producto deja de mostrarse pero se conserva el histórico.
  Future<void> deleteProduct(int id) async {
    final now = _nowIso();
    try {
      await _client.from('product').update({
        'deleted_at': now,
        'updated_at': now,
      }).eq('id', id);
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  /// Suma [delta] unidades al stock de un producto (negativo para quitarlas) y
  /// devuelve el stock resultante.
  ///
  /// Es la misma operación que usa `save_night` al guardar una lista: el stock
  /// siempre se mueve en unidades sueltas (botellines).
  Future<int> adjustStock(int productId, int delta) async {
    try {
      final stock = await _client.rpc('adjust_product_stock', params: {
        'p_product_id': productId,
        'p_delta': delta,
      });
      _changed();
      return (stock as num).toInt();
    } catch (error) {
      throw StateError(_friendly(error));
    }
  }

  // ---------------------------------------------------------------------------
  // Consumo
  // ---------------------------------------------------------------------------

  /// Guarda la lista de una noche y planta (sustituye la que hubiera de esa
  /// fecha y planta). Los productos no incluidos cuentan como consumo 0.
  Future<void> saveNight(String date, Floor floor, Map<int, int> qty) async {
    try {
      await _client.rpc('save_night', params: {
        'p_date': date,
        'p_floor': floor.db,
        'p_items': [
          for (final entry in qty.entries.where((e) => e.value > 0))
            {'product_id': entry.key, 'quantity': entry.value},
        ],
      });
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  /// Filas crudas de consumo, opcionalmente filtradas por fecha y planta.
  Future<List<Map<String, dynamic>>> _consumptionRows({
    String? since,
    Floor? floor,
  }) async {
    var query = _client
        .from('consumption')
        .select('quantity, product_id, night!inner(date, floor)');
    if (since != null) {
      query = query.gte('night.date', since);
    }
    if (floor != null) {
      query = query.eq('night.floor', floor.db);
    }
    return await query;
  }

  /// date -> (productId -> cantidad), sumando todas las plantas.
  ///
  /// Se usa para la previsión y los resúmenes globales. Para separar las listas
  /// por planta está [nightsByFloor] o el filtro [floor].
  Future<Map<String, Map<int, int>>> nights({
    String? since,
    Floor? floor,
  }) async {
    final rows = await _consumptionRows(since: since, floor: floor);
    final out = <String, Map<int, int>>{};
    for (final row in rows) {
      final night = row['night'];
      final date = night is Map ? night['date'] as String : night as String;
      final productId = row['product_id'] as int;
      final quantity = row['quantity'] as int;
      final day = out.putIfAbsent(date, () => {});
      day[productId] = (day[productId] ?? 0) + quantity;
    }
    return out;
  }

  /// date -> planta -> (productId -> cantidad).
  Future<Map<String, Map<Floor, Map<int, int>>>> nightsByFloor([
    String? since,
  ]) async {
    final rows = await _consumptionRows(since: since);
    final out = <String, Map<Floor, Map<int, int>>>{};
    for (final row in rows) {
      final night = row['night'];
      final date = night is Map ? night['date'] as String : night as String;
      final floor = Floor.fromDb(
        night is Map ? night['floor'] as String? : null,
      );
      final productId = row['product_id'] as int;
      final quantity = row['quantity'] as int;
      final byFloor = out.putIfAbsent(date, () => {});
      final day = byFloor.putIfAbsent(floor, () => {});
      day[productId] = (day[productId] ?? 0) + quantity;
    }
    return out;
  }

  /// Botellines guardados de una noche y planta (productId -> cantidad).
  Future<Map<int, int>> nightConsumption(String date, Floor floor) async {
    final rows = await _client
        .from('consumption')
        .select('product_id, quantity, night!inner(date, floor)')
        .eq('night.date', date)
        .eq('night.floor', floor.db);
    return {
      for (final row in rows) row['product_id'] as int: row['quantity'] as int,
    };
  }

  /// Última lista guardada, con su fecha y planta, o `null` si no hay ninguna.
  Future<({String date, Floor floor})?> latestNight() async {
    final rows = await _client
        .from('night')
        .select('date, floor, consumption!inner(id)')
        .order('date', ascending: false)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      date: row['date'] as String,
      floor: Floor.fromDb(row['floor'] as String?),
    );
  }

  // ---------------------------------------------------------------------------
  // Calendario de excepciones
  // ---------------------------------------------------------------------------

  Future<Map<String, SpecialDay>> specialDays() async {
    final rows = await _client.from('special_day').select();
    return {
      for (final row in rows)
        row['date'] as String:
            SpecialDay.fromMap(Map<String, Object?>.from(row)),
    };
  }

  Future<void> setSpecialDay(SpecialDay s) async {
    try {
      await _client.from('special_day').upsert({
        'date': s.date,
        'open': s.open,
        'note': s.note,
      });
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  Future<void> deleteSpecialDay(String date) async {
    try {
      await _client.from('special_day').delete().eq('date', date);
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Incidencias
  // ---------------------------------------------------------------------------

  /// Incidencias del local, de la más reciente a la más antigua.
  ///
  /// Cualquier persona del equipo puede leerlas; los filtros se aplican en el
  /// servidor para no traer histórico innecesario.
  Future<List<Incident>> incidents({
    Floor? floor,
    IncidentStatus? status,
    IncidentCategory? category,
  }) async {
    var query = _client.from('incident_view').select();
    if (floor != null) query = query.eq('floor', floor.db);
    if (status != null) query = query.eq('status', status.db);
    if (category != null) query = query.eq('category', category.db);
    final rows = await query.order('created_at', ascending: false);
    return [
      for (final row in rows) Incident.fromRow(Map<String, Object?>.from(row)),
    ];
  }

  /// Crea una incidencia ([Incident.id] nulo) o actualiza la existente.
  ///
  /// La RPC fija el autor al usuario de la sesión y comprueba que solo el
  /// administrador puede cambiar el estado. Devuelve el id guardado.
  Future<int> saveIncident(Incident incident) async {
    final error = incident.validationError;
    if (error != null) throw ArgumentError.value(incident, 'incident', error);
    try {
      final id = await _client.rpc('save_incident', params: {
        'p_id': incident.id,
        'p_floor': incident.floor.db,
        'p_category': incident.category.db,
        'p_title': incident.title.trim(),
        'p_description': incident.description.trim(),
        'p_status': incident.status.db,
      });
      _changed();
      return (id as num).toInt();
    } catch (error) {
      throw StateError(_friendly(error));
    }
  }

  /// Borra una incidencia. El administrador puede borrar cualquiera; el autor,
  /// solo mientras siga abierta.
  Future<void> deleteIncident(int id) async {
    try {
      await _client.rpc('delete_incident', params: {'p_id': id});
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Turnos: puestos, usuarios y turnos
  // ---------------------------------------------------------------------------

  /// Puestos configurados, ordenados por planta y nombre.
  Future<List<JobRole>> roles() async {
    final rows = await _client.from('job_role').select();
    final list = [
      for (final row in rows) JobRole.fromRow(Map<String, Object?>.from(row)),
    ];
    const order = {'planta_baja': 0, 'karaoke': 1, 'terraza': 2};
    list.sort((a, b) {
      final floor = (order[a.floor.db] ?? 2).compareTo(order[b.floor.db] ?? 2);
      return floor != 0 ? floor : a.name.compareTo(b.name);
    });
    return list;
  }

  Future<void> addRole(JobRole role) async {
    final name = normalizeRoleName(role.name);
    if (name.isEmpty) {
      throw ArgumentError('El nombre del puesto es obligatorio.');
    }
    try {
      await _client.from('job_role').insert({
        'name': name,
        'name_key': roleNameKey(name),
        'floor': role.floor.db,
        'note': role.note.trim(),
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw StateError('Ya existe un puesto con ese nombre.');
      }
      throw StateError(_friendly(error));
    }
    _changed();
  }

  Future<void> updateRole(JobRole role) async {
    if (role.id == null) {
      throw ArgumentError('El puesto debe tener un id.');
    }
    final name = normalizeRoleName(role.name);
    if (name.isEmpty) {
      throw ArgumentError('El nombre del puesto es obligatorio.');
    }
    try {
      await _client.from('job_role').update({
        'name': name,
        'name_key': roleNameKey(name),
        'floor': role.floor.db,
        'note': role.note.trim(),
      }).eq('id', role.id!);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw StateError('Ya existe un puesto con ese nombre.');
      }
      throw StateError(_friendly(error));
    }
    _changed();
  }

  /// Borra un puesto solo si no tiene usuarios ni turnos asignados.
  Future<void> deleteRole(int id) async {
    final users = await _client
        .from('profiles')
        .select('id')
        .eq('job_role_id', id)
        .limit(1);
    if (users.isNotEmpty) {
      throw StateError('No se puede borrar un puesto con usuarios asignados.');
    }
    final shifts =
        await _client.from('shift').select('id').eq('role_id', id).limit(1);
    if (shifts.isNotEmpty) {
      throw StateError('No se puede borrar un puesto con turnos históricos.');
    }
    await _client.from('job_role').delete().eq('id', id);
    _changed();
  }

  /// Usuarios (solo activos salvo [includeInactive]), con su puesto habitual.
  Future<List<AppUser>> users({bool includeInactive = false}) async {
    var query = _client.from('user_view').select();
    if (!includeInactive) {
      query = query.eq('active', 1);
    }
    final rows = await query;
    final list = [
      for (final row in rows) AppUser.fromRow(Map<String, Object?>.from(row)),
    ];
    const order = {'planta_baja': 0, 'karaoke': 1, 'terraza': 2};
    list.sort((a, b) {
      final floor = (order[a.jobRole?.floor.db] ?? 2)
          .compareTo(order[b.jobRole?.floor.db] ?? 2);
      if (floor != 0) return floor;
      final role = (a.jobRole?.name ?? '').compareTo(b.jobRole?.name ?? '');
      if (role != 0) return role;
      final name = a.name.compareTo(b.name);
      return name != 0 ? name : a.surname.compareTo(b.surname);
    });
    return list;
  }

  Future<AppUser?> userById(int id) async {
    final row =
        await _client.from('user_view').select().eq('id', id).maybeSingle();
    return row == null ? null : AppUser.fromRow(Map<String, Object?>.from(row));
  }

  Future<AppUser?> _profileByAuthId(String authId) async {
    final row = await _client
        .from('user_view')
        .select()
        .eq('auth_id', authId)
        .maybeSingle();
    return row == null ? null : AppUser.fromRow(Map<String, Object?>.from(row));
  }

  Future<bool> emailExists(String email, {int? exceptId}) async {
    var query = _client
        .from('profiles')
        .select('id')
        .eq('email', _normalizeEmail(email));
    if (exceptId != null) {
      query = query.neq('id', exceptId);
    }
    final rows = await query;
    return rows.isNotEmpty;
  }

  /// Crea una cuenta. La contraseña real la gestiona Supabase Auth; la Edge
  /// Function `admin-users` es la única que puede crear usuarios con clave
  /// temporal, porque necesita la clave secreta.
  Future<int> addUser(AppUser user, {required String password}) async {
    _validateUser(user);
    _validatePassword(password);
    if (await emailExists(user.email)) {
      throw StateError('Ya existe una cuenta con ese email.');
    }
    final data = await _invokeAdmin({
      'action': 'create',
      'email': _normalizeEmail(user.email),
      'name': user.name.trim(),
      'surname': user.surname.trim(),
      'password': password,
      'role': user.role.db,
      'job_role_id': user.jobRole?.id,
      'active': user.active,
      'opener': user.opener,
      'working_days': AppUser.formatWorkingDays(user.workingDays),
    });
    final id = data['id'];
    if (id is! num) {
      throw StateError('No se pudo crear la cuenta.');
    }
    _changed();
    return id.toInt();
  }

  /// Actualiza los datos del usuario. Si [password] no es nulo ni vacío,
  /// también cambia la contraseña.
  Future<void> updateUser(AppUser user, {String? password}) async {
    final id = user.id;
    if (id == null) throw ArgumentError('El usuario debe tener un id.');
    _validateUser(user);
    if (await emailExists(user.email, exceptId: id)) {
      throw StateError('Ya existe una cuenta con ese email.');
    }
    await _invokeAdmin({
      'action': 'update',
      'id': id,
      'email': _normalizeEmail(user.email),
      'name': user.name.trim(),
      'surname': user.surname.trim(),
      if (password != null && password.isNotEmpty) 'password': password,
      'role': user.role.db,
      'job_role_id': user.jobRole?.id,
      'active': user.active,
      'opener': user.opener,
      'working_days': AppUser.formatWorkingDays(user.workingDays),
    });
    _changed();
  }

  /// Baja lógica: conserva los turnos históricos.
  Future<void> setUserActive(int id, bool active) async {
    await _invokeAdmin({
      'action': 'setActive',
      'id': id,
      'active': active,
    });
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Foto de perfil
  // ---------------------------------------------------------------------------

  static const String _avatarBucket = 'avatars';

  /// URL pública de una foto guardada en el bucket `avatars`.
  String avatarPublicUrl(String path) =>
      _client.storage.from(_avatarBucket).getPublicUrl(path);

  /// Sube la foto de perfil del usuario actual y la asigna a su perfil.
  ///
  /// [bytes] debe llegar ya reducida (JPEG). Se guarda con un nombre único para
  /// que el CDN no sirva una imagen anterior y para que la fila de `profiles`
  /// cambie y el resto de dispositivos lo reciba por Realtime. Devuelve la
  /// ruta almacenada.
  Future<String> updateOwnAvatar({required Uint8List bytes}) async {
    final session = _client.auth.currentSession;
    if (session == null) throw StateError('No hay una sesión iniciada.');
    final current = await _profileByAuthId(session.user.id);
    final path =
        '${session.user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await _client.storage.from(_avatarBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
            ),
          );
    } catch (error) {
      throw StateError('No se pudo subir la imagen: ${_friendly(error)}');
    }

    try {
      await _client.rpc('set_own_avatar', params: {'p_path': path});
    } catch (error) {
      // Si no se pudo guardar la ruta, no dejamos el archivo huérfano.
      try {
        await _client.storage.from(_avatarBucket).remove([path]);
      } catch (_) {
        // Sin importancia: el archivo no está referenciado por ningún perfil.
      }
      throw StateError(_friendly(error));
    }

    final previous = current?.avatarPath;
    if (previous != null && previous.isNotEmpty && previous != path) {
      try {
        await _client.storage.from(_avatarBucket).remove([previous]);
      } catch (_) {
        // La foto nueva ya está asignada; un archivo antiguo no impide usar
        // la app.
      }
    }
    _changed();
    return path;
  }

  /// Quita la foto de perfil del usuario actual.
  Future<void> removeOwnAvatar() async {
    final session = _client.auth.currentSession;
    if (session == null) throw StateError('No hay una sesión iniciada.');
    final current = await _profileByAuthId(session.user.id);
    try {
      await _client.rpc('set_own_avatar', params: {'p_path': null});
    } catch (error) {
      throw StateError(_friendly(error));
    }

    final path = current?.avatarPath;
    if (path != null && path.isNotEmpty) {
      try {
        await _client.storage.from(_avatarBucket).remove([path]);
      } catch (_) {
        // El perfil ya no apunta a la imagen; el archivo sobrante no afecta.
      }
    }
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Autenticación y sesión
  // ---------------------------------------------------------------------------

  /// Comprueba email y contraseña y, si son correctos, abre la sesión.
  ///
  /// Devuelve `null` si las credenciales no coinciden. Lanza [StateError] si
  /// la cuenta existe pero está desactivada.
  Future<AppUser?> authenticate(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: _normalizeEmail(email),
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) return null;
      final user = await _profileByAuthId(authUser.id);
      if (user == null) {
        await _client.auth.signOut();
        return null;
      }
      if (!user.active) {
        await _client.auth.signOut();
        throw StateError('La cuenta está desactivada.');
      }
      return user;
    } on AuthException catch (error) {
      if (error.code == 'email_not_confirmed') {
        throw StateError('La cuenta todavía no está confirmada.');
      }
      if (error.code == 'user_banned') {
        throw StateError('La cuenta está desactivada.');
      }
      return null;
    }
  }

  /// Crea una cuenta desde el registro y la deja con la sesión iniciada.
  Future<AppUser> registerUser({
    required String name,
    required String surname,
    required String email,
    required String password,
  }) async {
    _validatePassword(password);
    final normalized = _normalizeEmail(email);
    if (!isValidEmail(normalized)) {
      throw ArgumentError('El email no es válido.');
    }
    final response = await _client.auth.signUp(
      email: normalized,
      password: password,
      data: {'name': name.trim(), 'surname': surname.trim()},
    );
    final authUser = response.user;
    if (authUser == null) {
      throw StateError('No se pudo crear la cuenta.');
    }
    if (response.session == null) {
      throw StateError(
        'Revisa tu correo para confirmar la cuenta antes de entrar.',
      );
    }
    final user = await _profileByAuthId(authUser.id);
    if (user == null) {
      throw StateError('No se pudo crear el perfil.');
    }
    // El usuario acaba de elegir su contraseña: no hay que forzar el cambio.
    try {
      await _client.rpc('mark_password_changed');
    } catch (_) {
      // No es crítico: si falla, el usuario podrá cambiarla desde Cuenta.
    }
    return user;
  }

  /// Usuario de la sesión actual, o `null` si no hay sesión válida.
  Future<AppUser?> currentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    final user = await _profileByAuthId(session.user.id);
    if (user == null || !user.active) {
      await _client.auth.signOut();
      return null;
    }
    return user;
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    await disconnectRealtime();
  }

  /// Cambia la contraseña verificando antes la actual.
  Future<void> changePassword(
    int userId,
    String currentPassword,
    String newPassword,
  ) async {
    _validatePassword(newPassword);
    final session = _client.auth.currentSession;
    if (session == null) {
      throw StateError('No hay una sesión iniciada.');
    }
    final email = session.user.email;
    if (email == null || email.isEmpty) {
      throw StateError('La cuenta no tiene un email asociado.');
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException {
      throw StateError('La contraseña actual no es correcta.');
    }

    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      await _client.rpc('mark_password_changed');
    } on AuthException catch (error) {
      throw StateError(error.message);
    }
    _changed();
  }

  /// Cambia la contraseña sin pedir la actual. Solo se usa en el cambio
  /// obligatorio tras entrar con la contraseña temporal, cuando la sesión ya
  /// está abierta con esas credenciales.
  Future<void> setPassword(String newPassword) async {
    _validatePassword(newPassword);
    if (_client.auth.currentSession == null) {
      throw StateError('No hay una sesión iniciada.');
    }
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      await _client.rpc('mark_password_changed');
    } on AuthException catch (error) {
      throw StateError(error.message);
    }
    _changed();
  }

  static void _validateUser(AppUser user) {
    if (user.name.trim().isEmpty) {
      throw ArgumentError('El nombre del usuario es obligatorio.');
    }
    if (!isValidEmail(user.email)) {
      throw ArgumentError('El email no es válido.');
    }
  }

  static void _validatePassword(String password) {
    if (password.length < 6) {
      throw ArgumentError('La contraseña debe tener al menos 6 caracteres.');
    }
  }

  // ---------------------------------------------------------------------------
  // Turnos
  // ---------------------------------------------------------------------------

  /// Turnos de un mes completo, ordenados por fecha y planta.
  Future<List<Shift>> shiftsForMonth(DateTime month) async {
    final first = Schedule.fmt(DateTime(month.year, month.month, 1));
    final last = Schedule.fmt(DateTime(month.year, month.month + 1, 0));
    final rows = await _client
        .from('shift')
        .select()
        .gte('date', first)
        .lte('date', last)
        .order('date')
        .order('floor')
        .order('role_name')
        .order('user_name');
    return [
      for (final row in rows) Shift.fromRow(Map<String, Object?>.from(row)),
    ];
  }

  /// Genera y guarda el horario de [month] a partir de los usuarios activos
  /// con puesto. Devuelve cuántos turnos se han creado.
  Future<int> generateMonthShifts(DateTime month) async {
    final users = (await this.users())
        .where((user) => user.jobRole != null)
        .toList(growable: false);
    final special = await specialDays();
    final generated = ShiftGenerator.generateMonth(
      month: month,
      users: users,
      specialDays: special,
    );
    await replaceMonthShifts(month, generated);
    return generated.length;
  }

  /// Sustituye todos los turnos del mes por [shifts].
  Future<void> replaceMonthShifts(DateTime month, List<Shift> shifts) async {
    final first = Schedule.fmt(DateTime(month.year, month.month, 1));
    final payload = [
      for (final shift in shifts)
        {
          'date': shift.date,
          'user_id': shift.userId,
          'user_name': shift.userName,
          'role_id': shift.roleId,
          'role_name': shift.roleName,
          'floor': shift.floor.db,
          'start_min': shift.startMin,
          'end_min': shift.endMin,
          'break_min': shift.breakMin,
          'status': shift.status.db,
          'note': shift.note.trim().isEmpty ? null : shift.note.trim(),
        },
    ];
    try {
      await _client.rpc('replace_month_shifts', params: {
        'p_month': first,
        'p_shifts': payload,
      });
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  Future<void> updateShift(Shift shift) async {
    final id = shift.id;
    if (id == null) {
      throw ArgumentError('El turno debe tener un id.');
    }
    final note = shift.note.trim();
    try {
      await _client.from('shift').update({
        'start_min': shift.startMin,
        'end_min': shift.endMin,
        'break_min': shift.breakMin,
        'status': shift.status.db,
        'note': note.isEmpty ? null : note,
      }).eq('id', id);
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  Future<void> deleteShift(int id) async {
    try {
      await _client.from('shift').delete().eq('id', id);
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  /// Pasa a publicado todos los borradores del mes.
  Future<void> publishMonth(DateTime month) async {
    final first = Schedule.fmt(DateTime(month.year, month.month, 1));
    try {
      await _client.rpc('publish_month', params: {'p_month': first});
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }

  Future<void> confirmShift(int id) async {
    try {
      await _client.rpc('confirm_my_shift', params: {'p_shift_id': id});
    } catch (error) {
      throw StateError(_friendly(error));
    }
    _changed();
  }
}
