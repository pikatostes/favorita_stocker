import 'package:flutter/material.dart';

import 'shifts.dart';

/// Motivo de una incidencia. Los valores de [db] deben coincidir con el
/// `check` de `public.incident.category`; [label] e [icon] son solo de UI.
enum IncidentCategory {
  appliance('electrodomestico', 'Electrodoméstico', Icons.kitchen_outlined),
  electricity('electricidad', 'Electricidad', Icons.electrical_services),
  plumbing('fontaneria', 'Fontanería', Icons.plumbing_outlined),
  furniture('mobiliario', 'Mobiliario', Icons.chair_outlined),
  cleaning('limpieza', 'Limpieza', Icons.cleaning_services_outlined),
  stock('stock', 'Falta de stock', Icons.inventory_2_outlined),
  other('otro', 'Otro', Icons.more_horiz);

  const IncidentCategory(this.db, this.label, this.icon);

  final String db;
  final String label;
  final IconData icon;

  static IncidentCategory fromDb(String? value) => values.firstWhere(
        (category) => category.db == value,
        orElse: () => IncidentCategory.other,
      );
}

/// Estado de seguimiento de una incidencia.
///
/// La abre cualquier empleado; el administrador la mueve a «En proceso» y a
/// «Resuelta». Mientras está abierta, su autor puede corregir los datos.
enum IncidentStatus {
  open('abierta', 'Abierta'),
  inProgress('en_proceso', 'En proceso'),
  resolved('resuelta', 'Resuelta');

  const IncidentStatus(this.db, this.label);

  final String db;
  final String label;

  bool get isOpen => this == IncidentStatus.open;
  bool get isResolved => this == IncidentStatus.resolved;

  static IncidentStatus fromDb(String? value) => values.firstWhere(
        (status) => status.db == value,
        orElse: () => IncidentStatus.open,
      );
}

/// Incidencia declarada por un usuario del local.
///
/// Cada incidencia pertenece a un único usuario ([userId]) y a una planta
/// ([floor]). El nombre del autor llega ya resuelto desde `incident_view` para
/// poder pintar el listado sin consultas adicionales.
class Incident {
  final int? id;
  final int userId;
  final String userName;
  final Floor floor;
  final IncidentCategory category;
  final String title;
  final String description;
  final IncidentStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const Incident({
    this.id,
    required this.userId,
    required this.userName,
    required this.floor,
    required this.category,
    required this.title,
    this.description = '',
    this.status = IncidentStatus.open,
    required this.createdAt,
    this.resolvedAt,
  });

  factory Incident.fromRow(Map<String, Object?> row) {
    final created = DateTime.tryParse((row['created_at'] as String?) ?? '');
    final resolved = DateTime.tryParse((row['resolved_at'] as String?) ?? '');
    final name = (row['user_name'] as String?) ?? '';
    final surname = (row['user_surname'] as String?) ?? '';
    return Incident(
      id: row['id'] as int?,
      userId: (row['user_id'] as int?) ?? 0,
      userName: [name.trim(), surname.trim()]
          .where((part) => part.isNotEmpty)
          .join(' '),
      floor: Floor.fromDb(row['floor'] as String?),
      category: IncidentCategory.fromDb(row['category'] as String?),
      title: (row['title'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      status: IncidentStatus.fromDb(row['status'] as String?),
      createdAt: created?.toLocal() ?? DateTime.now(),
      resolvedAt: resolved?.toLocal(),
    );
  }

  String? get validationError {
    if (title.trim().isEmpty) return 'El título es obligatorio.';
    return null;
  }

  Incident copyWith({
    int? id,
    int? userId,
    String? userName,
    Floor? floor,
    IncidentCategory? category,
    String? title,
    String? description,
    IncidentStatus? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) =>
      Incident(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        floor: floor ?? this.floor,
        category: category ?? this.category,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        resolvedAt: resolvedAt ?? this.resolvedAt,
      );

  /// `true` si [userId] es el autor y todavía se puede editar.
  bool canEdit(int? currentUserId) => userId == currentUserId && status.isOpen;
}
