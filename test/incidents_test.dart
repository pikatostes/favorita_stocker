import 'package:flutter_test/flutter_test.dart';
import 'package:stock_bar/incidents.dart';
import 'package:stock_bar/shifts.dart';

Incident _row({
  String floor = 'karaoke',
  String category = 'electrodomestico',
  String status = 'abierta',
  String? resolvedAt,
}) =>
    Incident.fromRow({
      'id': 7,
      'user_id': 3,
      'user_name': 'Ana',
      'user_surname': 'Ruiz',
      'floor': floor,
      'category': category,
      'title': 'Nevera del karaoke',
      'description': 'No enfría desde ayer',
      'status': status,
      'created_at': '2026-11-12T20:30:00Z',
      'resolved_at': resolvedAt,
    });

void main() {
  test('lee la incidencia con autor, planta y categoría', () {
    final incident = _row();

    expect(incident.id, 7);
    expect(incident.userId, 3);
    expect(incident.userName, 'Ana Ruiz');
    expect(incident.floor, Floor.karaoke);
    expect(incident.category, IncidentCategory.appliance);
    expect(incident.status, IncidentStatus.open);
    expect(incident.description, 'No enfría desde ayer');
    expect(incident.createdAt.isUtc, isFalse);
  });

  test('las categorías desconocidas caen en «Otro»', () {
    expect(
      IncidentCategory.fromDb('inventada'),
      IncidentCategory.other,
    );
    expect(IncidentCategory.fromDb('limpieza'), IncidentCategory.cleaning);
  });

  test('el estado resuelto conserva la fecha de resolución', () {
    final incident = _row(
      status: 'resuelta',
      resolvedAt: '2026-11-13T09:00:00Z',
    );

    expect(incident.status.isResolved, isTrue);
    expect(incident.resolvedAt, isNotNull);
  });

  test('solo el autor puede editar una incidencia abierta', () {
    final incident = _row();

    expect(incident.canEdit(3), isTrue);
    expect(incident.canEdit(4), isFalse);
    expect(incident.canEdit(null), isFalse);
    expect(
      _row(status: 'en_proceso').canEdit(3),
      isFalse,
    );
  });

  test('el título es obligatorio', () {
    final incident = Incident(
      userId: 1,
      userName: 'Ana',
      floor: Floor.plantaBaja,
      category: IncidentCategory.other,
      title: '   ',
      createdAt: DateTime(2026, 11, 12),
    );

    expect(incident.validationError, 'El título es obligatorio.');
    expect(
      incident.copyWith(title: 'Puerta rota').validationError,
      isNull,
    );
  });
}
