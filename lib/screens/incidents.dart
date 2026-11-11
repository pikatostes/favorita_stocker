import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_design.dart';
import '../auth_controller.dart';
import '../db.dart';
import '../incidents.dart';
import '../shifts.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_ui.dart';
import '../widgets/shift_ui.dart';

/// Listado de incidencias del local.
///
/// Cualquier miembro del equipo puede declarar una incidencia y consultar las
/// del resto. El autor puede corregir o borrar la suya mientras siga abierta;
/// el administrador puede editar cualquiera y moverla de estado.
class IncidentsScreen extends StatefulWidget {
  /// Cuando se muestra dentro de [AdminScreen] no crea AppBar propia.
  final bool embedded;

  /// Abre directamente el formulario de alta al entrar (acceso «Reportar
  /// incidencia» desde Inicio).
  final bool startNew;

  const IncidentsScreen({
    super.key,
    this.embedded = false,
    this.startNew = false,
  });

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  Floor? _floor;
  IncidentCategory? _category;
  IncidentStatus? _status;
  late Future<List<Incident>> _future = _load();

  bool get _isAdmin => AuthController.i.user?.role == UserRole.admin;
  int? get _currentUserId => AuthController.i.user?.id;

  Future<List<Incident>> _load() => Db.i.incidents(
        floor: _floor,
        status: _status,
        category: _category,
      );

  void _reload() {
    if (mounted) setState(() => _future = _load());
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  void _applyFilters() {
    setState(() => _future = _load());
  }

  @override
  void initState() {
    super.initState();
    Db.i.version.addListener(_reload);
    if (widget.startNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openForm();
      });
    }
  }

  @override
  void dispose() {
    Db.i.version.removeListener(_reload);
    super.dispose();
  }

  Floor get _defaultFloor =>
      _floor ?? AuthController.i.user?.jobRole?.floor ?? Floor.plantaBaja;

  Future<void> _openForm([Incident? incident]) async {
    final result = await showDialog<Incident>(
      context: context,
      builder: (_) => _IncidentDialog(
        incident: incident,
        isAdmin: _isAdmin,
        defaultFloor: _defaultFloor,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await Db.i.saveIncident(result);
      if (!mounted) return;
      showAppSnack(
        context,
        incident == null ? 'Incidencia registrada.' : 'Incidencia actualizada.',
        tone: AppTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, describeDbError(error), tone: AppTone.danger);
    }
  }

  Future<void> _changeStatus(
    Incident incident,
    IncidentStatus status,
  ) async {
    if (incident.status == status) return;
    try {
      await Db.i.saveIncident(incident.copyWith(status: status));
      if (!mounted) return;
      showAppSnack(context, 'Estado actualizado.', tone: AppTone.success);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, describeDbError(error), tone: AppTone.danger);
    }
  }

  Future<void> _delete(Incident incident) async {
    final id = incident.id;
    if (id == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Borrar incidencia',
      message: '¿Quieres borrar «${incident.title}»?',
      confirmLabel: 'Borrar',
    );
    if (!ok || !mounted) return;
    try {
      await Db.i.deleteIncident(id);
      if (!mounted) return;
      showAppSnack(context, 'Incidencia borrada.', tone: AppTone.success);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, describeDbError(error), tone: AppTone.danger);
    }
  }

  Widget _filterField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T?>> items,
    required ValueChanged<T?> onChanged,
    required double width,
  }) =>
      SizedBox(
        width: width,
        child: DropdownButtonFormField<T?>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: items,
          onChanged: (selected) {
            onChanged(selected);
            _applyFilters();
          },
        ),
      );

  Widget _filters() => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filterField<Floor>(
                label: 'Planta',
                value: _floor,
                width: 190,
                items: [
                  const DropdownMenuItem<Floor?>(
                    value: null,
                    child: Text('Todas las plantas'),
                  ),
                  for (final floor in Floor.values)
                    DropdownMenuItem<Floor?>(
                      value: floor,
                      child: Text(floor.label),
                    ),
                ],
                onChanged: (value) => setState(() => _floor = value),
              ),
              _filterField<IncidentCategory>(
                label: 'Categoría',
                value: _category,
                width: 210,
                items: [
                  const DropdownMenuItem<IncidentCategory?>(
                    value: null,
                    child: Text('Todas las categorías'),
                  ),
                  for (final category in IncidentCategory.values)
                    DropdownMenuItem<IncidentCategory?>(
                      value: category,
                      child: Text(category.label),
                    ),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              _filterField<IncidentStatus>(
                label: 'Estado',
                value: _status,
                width: 190,
                items: [
                  const DropdownMenuItem<IncidentStatus?>(
                    value: null,
                    child: Text('Todos los estados'),
                  ),
                  for (final status in IncidentStatus.values)
                    DropdownMenuItem<IncidentStatus?>(
                      value: status,
                      child: Text(status.label),
                    ),
                ],
                onChanged: (value) => setState(() => _status = value),
              ),
            ],
          ),
        ),
      );

  Widget _summary(List<Incident> incidents) {
    final open = incidents
        .where((incident) => incident.status == IncidentStatus.open)
        .length;
    final inProgress = incidents
        .where((incident) => incident.status == IncidentStatus.inProgress)
        .length;
    final resolved = incidents
        .where((incident) => incident.status == IncidentStatus.resolved)
        .length;
    if (incidents.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        StatusPill(
          label: '$open abierta${open == 1 ? '' : 's'}',
          icon: Icons.error_outline,
          tone: AppTone.warning,
          dense: true,
        ),
        StatusPill(
          label: '$inProgress en proceso',
          icon: Icons.build_outlined,
          tone: AppTone.info,
          dense: true,
        ),
        StatusPill(
          label: '$resolved resuelta${resolved == 1 ? '' : 's'}',
          icon: Icons.check_circle_outline,
          tone: AppTone.success,
          dense: true,
        ),
      ],
    );
  }

  Widget _content(List<Incident> incidents) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            widget.embedded ? AppSpacing.md : AppSpacing.lg,
            AppSpacing.md,
            widget.embedded ? AppSpacing.md : AppSpacing.lg,
            // Hueco para que el FAB no tape las acciones de la última tarjeta.
            AppSpacing.xxxl * 2,
          ),
          children: [
            AppContentFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(
                    eyebrow: 'Operación',
                    title: 'Incidencias',
                    subtitle:
                        'Avisos y averías del local, con su planta y responsable.',
                    compact: widget.embedded,
                    actions: [
                      FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add_alert_outlined, size: 18),
                        label: const Text('Nueva incidencia'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _filters(),
                  const SizedBox(height: AppSpacing.md),
                  if (incidents.isNotEmpty) ...[
                    _summary(incidents),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (incidents.isEmpty)
                    const AppEmptyState(
                      icon: Icons.task_alt,
                      title: 'Sin incidencias',
                      message:
                          'No hay incidencias que coincidan con los filtros. '
                          'Pulsa «Nueva incidencia» para registrar una.',
                    )
                  else
                    for (final incident in incidents) ...[
                      _IncidentCard(
                        incident: incident,
                        isAdmin: _isAdmin,
                        canEdit: _isAdmin || incident.canEdit(_currentUserId),
                        onEdit: () => _openForm(incident),
                        onDelete: () => _delete(incident),
                        onStatus: (status) => _changeStatus(incident, status),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.embedded ? null : AppBar(title: const AppLogo()),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Nueva incidencia',
          onPressed: () => _openForm(),
          child: const Icon(Icons.add),
        ),
        body: FutureBuilder<List<Incident>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorState(
                title: 'No se pudieron cargar las incidencias.',
                error: snapshot.error!,
                onRetry: _reload,
              );
            }
            if (!snapshot.hasData) {
              return const AppLoadingState(label: 'Cargando incidencias…');
            }
            return _content(snapshot.data!);
          },
        ),
      );
}

/// Tarjeta de una incidencia con su autor, planta, categoría y estado.
class _IncidentCard extends StatelessWidget {
  final Incident incident;
  final bool isAdmin;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<IncidentStatus> onStatus;

  const _IncidentCard({
    required this.incident,
    required this.isAdmin,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
  });

  static final DateFormat _dateFormat = DateFormat("d MMM yyyy · HH:mm", 'es');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final canDelete = isAdmin || canEdit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(
                    incident.category.icon,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${incident.category.label} · '
                        '${incident.floor.label}',
                        style: muted,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${incident.userName} · '
                        '${_dateFormat.format(incident.createdAt)}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _statusPill(incident.status),
              ],
            ),
            if (incident.description.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                incident.description.trim(),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (isAdmin || canDelete) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isAdmin)
                    PopupMenuButton<IncidentStatus>(
                      tooltip: 'Cambiar estado',
                      onSelected: onStatus,
                      itemBuilder: (_) => [
                        for (final status in IncidentStatus.values)
                          PopupMenuItem(
                            value: status,
                            child: Row(
                              children: [
                                Icon(
                                  _statusIcon(status),
                                  size: 18,
                                  color: status == incident.status
                                      ? theme.colorScheme.primary
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(status.label),
                              ],
                            ),
                          ),
                      ],
                    ),
                  if (canEdit)
                    IconButton(
                      tooltip: 'Editar incidencia',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                  if (canDelete)
                    IconButton(
                      tooltip: 'Borrar incidencia',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusPill(IncidentStatus status) => StatusPill(
        label: status.label,
        icon: _statusIcon(status),
        tone: switch (status) {
          IncidentStatus.open => AppTone.warning,
          IncidentStatus.inProgress => AppTone.info,
          IncidentStatus.resolved => AppTone.success,
        },
        dense: true,
      );
}

IconData _statusIcon(IncidentStatus status) => switch (status) {
      IncidentStatus.open => Icons.error_outline,
      IncidentStatus.inProgress => Icons.build_outlined,
      IncidentStatus.resolved => Icons.check_circle_outline,
    };

/// Formulario de alta/edición de una incidencia.
///
/// Devuelve la incidencia rellena al confirmar; la pantalla es quien llama a
/// [Db.saveIncident] para poder mostrar el resultado en un SnackBar.
class _IncidentDialog extends StatefulWidget {
  final Incident? incident;
  final bool isAdmin;
  final Floor defaultFloor;

  const _IncidentDialog({
    required this.incident,
    required this.isAdmin,
    required this.defaultFloor,
  });

  @override
  State<_IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<_IncidentDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late Floor _floor;
  late IncidentCategory _category;
  late IncidentStatus _status;

  bool get _editing => widget.incident != null;

  @override
  void initState() {
    super.initState();
    final incident = widget.incident;
    _title = TextEditingController(text: incident?.title ?? '');
    _description = TextEditingController(text: incident?.description ?? '');
    _floor = incident?.floor ?? widget.defaultFloor;
    _category = incident?.category ?? IncidentCategory.appliance;
    _status = incident?.status ?? IncidentStatus.open;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final user = AuthController.i.user;
    final current = widget.incident;
    Navigator.pop(
      context,
      Incident(
        id: current?.id,
        userId: current?.userId ?? user?.id ?? 0,
        userName: current?.userName ?? user?.fullName ?? '',
        floor: _floor,
        category: _category,
        title: _title.text.trim(),
        description: _description.text.trim(),
        status: widget.isAdmin ? _status : IncidentStatus.open,
        createdAt: current?.createdAt ?? DateTime.now(),
        resolvedAt: current?.resolvedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_editing ? 'Editar incidencia' : 'Nueva incidencia'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<Floor>(
                  initialValue: _floor,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Planta'),
                  items: [
                    for (final floor in Floor.values)
                      DropdownMenuItem(
                        value: floor,
                        child: Row(
                          children: [
                            Icon(floorIcon(floor), size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Text(floor.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _floor = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<IncidentCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final category in IncidentCategory.values)
                      DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Icon(category.icon, size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Text(category.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                if (_editing && widget.isAdmin) ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<IncidentStatus>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: [
                      for (final status in IncidentStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _status = value);
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    hintText: 'Qué ocurre y dónde',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Escribe un título para la incidencia.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Detalles útiles para poder resolverla',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _save,
            child: Text(_editing ? 'Guardar' : 'Registrar'),
          ),
        ],
      );
}
