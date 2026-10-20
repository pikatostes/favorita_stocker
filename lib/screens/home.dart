import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth_controller.dart';
import '../db.dart';
import '../models.dart';
import '../prediction.dart';
import '../schedule.dart';
import '../shifts.dart';
import '../widgets/app_logo.dart';
import 'admin.dart';
import 'cuenta.dart';
import 'prevision.dart';
import 'registro.dart';
import 'turnos.dart';

/// Pestañas de la aplicación. Las marcadas como [adminOnly] solo se muestran
/// cuando el usuario tiene el rol [UserRole.admin].
enum HomeTab {
  start('Inicio', Icons.home_outlined),
  list('Lista', Icons.edit_note),
  forecast('Previsión', Icons.insights),
  shifts('Turnos', Icons.groups),
  admin('Admin', Icons.admin_panel_settings, adminOnly: true),
  account('Cuenta', Icons.account_circle_outlined);

  final String label;
  final IconData icon;
  final bool adminOnly;

  const HomeTab(this.label, this.icon, {this.adminOnly = false});
}

/// Pestañas visibles para [role]. Los empleados no ven la zona de Admin.
List<HomeTab> visibleHomeTabs(UserRole role) => [
      for (final tab in HomeTab.values)
        if (!tab.adminOnly || role == UserRole.admin) tab,
    ];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeTab _tab = HomeTab.start;

  @override
  void initState() {
    super.initState();
    AuthController.i.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthController.i.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final role = AuthController.i.user?.role ?? UserRole.employee;
    final tabs = visibleHomeTabs(role);
    setState(() {
      // Si el usuario deja de ser admin mientras está en una pestaña
      // restringida, vuelve a la pestaña de Inicio.
      if (!tabs.contains(_tab)) _tab = HomeTab.start;
    });
  }

  void _goTo(HomeTab tab) {
    final role = AuthController.i.user?.role ?? UserRole.employee;
    if (!visibleHomeTabs(role).contains(tab)) return;
    setState(() => _tab = tab);
  }

  Widget _pageFor(HomeTab tab) => switch (tab) {
        HomeTab.start => _HomeDashboard(onNavigate: _goTo),
        HomeTab.list => const RegistroScreen(),
        HomeTab.forecast => const PrevisionScreen(),
        HomeTab.shifts => const TurnosScreen(),
        HomeTab.admin => const AdminScreen(),
        HomeTab.account => const CuentaScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final role = AuthController.i.user?.role ?? UserRole.employee;
    final tabs = visibleHomeTabs(role);
    final selected = tabs.contains(_tab) ? tabs.indexOf(_tab) : 0;
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selected,
          children: [for (final tab in tabs) _pageFor(tab)],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => _goTo(tabs[i]),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inicio
// ---------------------------------------------------------------------------

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

String _longDate(DateTime date) =>
    _capitalize(DateFormat('EEEE d MMMM', 'es').format(date));

String _shortDate(DateTime date) =>
    _capitalize(DateFormat('EEE d MMM', 'es').format(date));

String _monthLabel(DateTime date) =>
    _capitalize(DateFormat('MMMM yyyy', 'es').format(date));

IconData _floorIcon(Floor floor) => switch (floor) {
      Floor.plantaBaja => Icons.storefront,
      Floor.karaoke => Icons.mic,
      Floor.terraza => Icons.deck,
    };

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _HomeData {
  final DateTime now;
  final DateTime serviceDay;
  final DateTime focusDay;
  final DateTime nextOpen;
  final bool openNow;
  final bool opensLaterToday;
  final Map<String, SpecialDay> special;
  final List<AppUser> users;
  final List<Shift> monthShifts;
  final List<Shift> focusShifts;
  final List<Shift> myUpcoming;
  final bool mySchedulePending;
  final ForecastResult? forecast;

  const _HomeData({
    required this.now,
    required this.serviceDay,
    required this.focusDay,
    required this.nextOpen,
    required this.openNow,
    required this.opensLaterToday,
    required this.special,
    required this.users,
    required this.monthShifts,
    required this.focusShifts,
    required this.myUpcoming,
    required this.mySchedulePending,
    required this.forecast,
  });

  DateTime get month => DateTime(now.year, now.month);

  bool get focusIsService => Schedule.fmt(focusDay) == Schedule.fmt(serviceDay);

  bool get focusIsTonight =>
      focusIsService ||
      Schedule.fmt(focusDay) == Schedule.fmt(Schedule.day(now));
}

class _HomeDashboard extends StatefulWidget {
  final ValueChanged<HomeTab> onNavigate;

  const _HomeDashboard({required this.onNavigate});

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  late Future<_HomeData> _future = _load();
  bool _working = false;

  Future<_HomeData> _load() async {
    final now = DateTime.now();
    final user = AuthController.i.user;
    final isAdmin = user?.role == UserRole.admin;

    final special = await Db.i.specialDays();
    final serviceDay = Schedule.serviceDay(now);
    final serviceOpen = Schedule.isOpen(serviceDay, special);
    final openNow = serviceOpen &&
        (now.hour >= Schedule.openHour || now.hour < Schedule.closeHour);
    final today = Schedule.day(now);
    final opensLaterToday =
        Schedule.isOpen(today, special) && now.hour < Schedule.openHour;
    final nextOpen = Schedule.nextOpen(now, special);
    final focusDay = openNow ? serviceDay : nextOpen;

    final month = DateTime(now.year, now.month);
    final monthShifts = await Db.i.shiftsForMonth(month);

    // El foco puede caer en el mes siguiente (o en el anterior si estamos de
    // madrugada el día 1), así que se consulta su mes cuando hace falta.
    final focusMonth = DateTime(focusDay.year, focusDay.month);
    final focusMonthShifts =
        focusMonth.year == month.year && focusMonth.month == month.month
            ? monthShifts
            : await Db.i.shiftsForMonth(focusMonth);
    final focusKey = Schedule.fmt(focusDay);
    final focusShifts =
        focusMonthShifts.where((shift) => shift.date == focusKey).toList();

    final users = await Db.i.users(includeInactive: isAdmin);

    ForecastResult? forecast;
    if (isAdmin) {
      try {
        forecast = await Predictor.forecast(nextOpen);
      } catch (error) {
        // La previsión es información secundaria: si falla, el resto del
        // Inicio debe seguir siendo utilizable.
        debugPrint('No se pudo calcular la previsión de Inicio: $error');
      }
    }

    var myUpcoming = <Shift>[];
    var mySchedulePending = false;
    if (user != null && !isAdmin) {
      // Antes de las 04:00 seguimos en la noche de servicio anterior; a partir
      // de esa hora, el siguiente turno se busca desde el día natural de hoy.
      final from = now.hour < Schedule.closeHour
          ? Schedule.fmt(serviceDay)
          : Schedule.fmt(today);
      final nextMonth = DateTime(month.year, month.month + 1);
      final nextMonthShifts = await Db.i.shiftsForMonth(nextMonth);
      final mySource = <Shift>[...monthShifts, ...nextMonthShifts];
      // Si estamos de madrugada el día 1, el servicio en curso pertenece al
      // mes anterior.
      if (openNow &&
          (focusMonth.year != month.year || focusMonth.month != month.month)) {
        mySource.addAll(focusMonthShifts);
      }
      final myAll = mySource
          .where((shift) =>
              shift.userId == user.id && shift.date.compareTo(from) >= 0)
          .toList()
        ..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.startMin.compareTo(b.startMin);
        });
      myUpcoming = myAll
          .where((shift) => shift.status != ShiftStatus.draft)
          .toList(growable: false);
      mySchedulePending = myUpcoming.isEmpty && myAll.isNotEmpty;
    }

    return _HomeData(
      now: now,
      serviceDay: serviceDay,
      focusDay: focusDay,
      nextOpen: nextOpen,
      openNow: openNow,
      opensLaterToday: opensLaterToday,
      special: special,
      users: users,
      monthShifts: monthShifts,
      focusShifts: focusShifts,
      myUpcoming: myUpcoming,
      mySchedulePending: mySchedulePending,
      forecast: forecast,
    );
  }

  void _reload() {
    if (mounted) setState(() => _future = _load());
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  void initState() {
    super.initState();
    Db.i.version.addListener(_reload);
    AuthController.i.addListener(_reload);
  }

  @override
  void dispose() {
    Db.i.version.removeListener(_reload);
    AuthController.i.removeListener(_reload);
    super.dispose();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Continuar',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _generateMonth(_HomeData data) async {
    if (_working) return;
    final hasEligibleUsers = data.users.any(
      (user) => user.active && user.jobRole != null,
    );
    if (!hasEligibleUsers) {
      _snack(
        context,
        'Añade puestos y usuarios activos para poder generar el horario.',
      );
      return;
    }
    final month = DateTime(data.now.year, data.now.month);
    if (data.monthShifts.isNotEmpty) {
      final ok = await _confirm(
        title: 'Regenerar ${_monthLabel(month)}',
        message: 'Se borrarán los turnos actuales de este mes y se generarán '
            'de nuevo. Los cambios manuales se perderán.',
        confirmLabel: 'Regenerar',
      );
      if (!ok || !mounted) return;
    }

    setState(() => _working = true);
    try {
      final count = await Db.i.generateMonthShifts(month);
      if (!mounted) return;
      _snack(context, 'Generados $count turnos.');
    } catch (error) {
      if (!mounted) return;
      _snack(context, 'No se pudo generar el horario: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _publishMonth(_HomeData data) async {
    if (_working) return;
    final drafts = data.monthShifts
        .where((shift) => shift.status == ShiftStatus.draft)
        .length;
    if (drafts == 0) {
      _snack(context, 'No hay turnos en borrador para publicar.');
      return;
    }
    final month = DateTime(data.now.year, data.now.month);
    final ok = await _confirm(
      title: 'Publicar ${_monthLabel(month)}',
      message: 'Se publicarán $drafts turnos. Los empleados podrán verlos en '
          'su horario.',
      confirmLabel: 'Publicar',
    );
    if (!ok || !mounted) return;

    setState(() => _working = true);
    try {
      await Db.i.publishMonth(month);
      if (!mounted) return;
      _snack(context, 'Turnos publicados.');
    } catch (error) {
      if (!mounted) return;
      _snack(context, 'No se pudieron publicar los turnos: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppLogo()),
      body: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(
              error: snapshot.error!,
              onRetry: _reload,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final user = AuthController.i.user;
          final isAdmin = user?.role == UserRole.admin;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                _header(data, user),
                if (isAdmin) ...[
                  _adminTonightCard(data),
                  _adminMonthCard(data),
                  _adminForecastCard(data),
                  _adminWarningsCard(data),
                ] else ...[
                  _myShiftCard(data, user),
                  _myHoursCard(data, user),
                  _employeeTonightCard(data),
                  _employeeNoticeCard(data),
                ],
                _quickActionsCard(isAdmin),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Comunes
  // -------------------------------------------------------------------------

  Widget _header(_HomeData data, AppUser? user) {
    final theme = Theme.of(context);
    final name =
        user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'equipo';
    final status = data.openNow
        ? 'Abierto ahora'
        : data.opensLaterToday
            ? 'Abre esta noche'
            : 'Cerrado';
    final statusColor = data.openNow || data.opensLaterToday
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final statusIcon = data.openNow || data.opensLaterToday
        ? Icons.nightlife
        : Icons.nightlight_round;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    user?.initial ?? '?',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, $name',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _longDate(data.now),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: Icon(statusIcon, size: 18, color: statusColor),
                  label: Text(status),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  side: BorderSide.none,
                ),
                Chip(
                  label: Text(user?.role.label ?? UserRole.employee.label),
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  side: BorderSide.none,
                ),
                Text(
                  data.openNow
                      ? 'Servicio: ${_shortDate(data.serviceDay)}'
                      : 'Próxima apertura: ${_shortDate(data.nextOpen)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (user?.role == UserRole.admin) _nextSpecialLine(data),
          ],
        ),
      ),
    );
  }

  Widget _nextSpecialLine(_HomeData data) {
    final label = _nextSpecialLabel(data);
    if (label == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.event_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _nextSpecialLabel(_HomeData data) {
    final todayKey = Schedule.fmt(Schedule.day(data.now));
    final upcoming = data.special.entries
        .where((entry) => entry.key.compareTo(todayKey) >= 0)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (upcoming.isEmpty) return null;
    final entry = upcoming.first;
    final note = entry.value.note.trim();
    final action = entry.value.open ? 'apertura' : 'cierre';
    return 'Calendario: ${_shortDate(DateTime.parse(entry.key))} · $action'
        '${note.isEmpty ? '' : ' · $note'}';
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _mutedText(String text) => Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );

  Widget _quickActionsCard(bool isAdmin) {
    return _sectionCard(
      icon: Icons.bolt,
      title: 'Accesos rápidos',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _quickAction(Icons.edit_note, 'Lista', HomeTab.list),
            _quickAction(Icons.insights, 'Previsión', HomeTab.forecast),
            _quickAction(Icons.groups, 'Turnos', HomeTab.shifts),
            if (isAdmin)
              _quickAction(
                Icons.admin_panel_settings,
                'Admin',
                HomeTab.admin,
              ),
            _quickAction(
              Icons.account_circle_outlined,
              'Cuenta',
              HomeTab.account,
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, HomeTab tab) {
    return OutlinedButton.icon(
      onPressed: () => widget.onNavigate(tab),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  // -------------------------------------------------------------------------
  // Administrador
  // -------------------------------------------------------------------------

  Widget _adminTonightCard(_HomeData data) {
    final theme = Theme.of(context);
    final shifts = data.focusShifts;
    final drafts =
        shifts.where((shift) => shift.status == ShiftStatus.draft).length;
    final activeUsers = data.users
        .where((user) => user.active && user.jobRole != null)
        .toList();
    final noOpener = <Floor>{};
    for (final floor in Floor.values) {
      final hasOpener = activeUsers.any(
        (user) =>
            user.jobRole!.floor == floor &&
            user.opener &&
            (user.workingDays.isEmpty ||
                user.workingDays.contains(data.focusDay.weekday)),
      );
      if (!hasOpener) noOpener.add(floor);
    }

    final subtitle = [
      _longDate(data.focusDay),
      if (drafts > 0) '$drafts en borrador',
    ].join(' · ');

    return _sectionCard(
      icon: Icons.nightlife,
      title: data.focusIsTonight ? 'Esta noche' : 'Próxima noche',
      subtitle: subtitle,
      action: TextButton(
        onPressed: () => widget.onNavigate(HomeTab.shifts),
        child: const Text('Ver turnos'),
      ),
      children: [
        if (shifts.isEmpty)
          _mutedText('Aún no hay turnos generados para esa noche.')
        else
          for (final floor in Floor.values)
            _teamRow(
              floor: floor,
              shifts: shifts.where((shift) => shift.floor == floor).toList(),
              warning: noOpener.contains(floor)
                  ? 'Falta un opener disponible en esta planta.'
                  : null,
              showStatus: true,
            ),
        if (noOpener.isNotEmpty) ...[
          const Divider(height: 20),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hay plantas sin opener para esa noche. Revisa los puestos '
                  'y los días disponibles del equipo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _adminMonthCard(_HomeData data) {
    final theme = Theme.of(context);
    final draft = data.monthShifts
        .where((shift) => shift.status == ShiftStatus.draft)
        .length;
    final published = data.monthShifts
        .where((shift) => shift.status == ShiftStatus.published)
        .length;
    final confirmed = data.monthShifts
        .where((shift) => shift.status == ShiftStatus.confirmed)
        .length;
    final withoutShifts = _openDaysWithoutShifts(data);
    final hasEligibleUsers = data.users.any(
      (user) => user.active && user.jobRole != null,
    );

    return _sectionCard(
      icon: Icons.event_note,
      title: 'Turnos de ${_monthLabel(data.month)}',
      subtitle: '${data.monthShifts.length} turnos en total',
      children: [
        Row(
          children: [
            _stat('$draft', 'Borradores', theme.colorScheme.onSurfaceVariant),
            _stat('$published', 'Publicados', theme.colorScheme.primary),
            _stat('$confirmed', 'Confirmados', theme.colorScheme.tertiary),
          ],
        ),
        if (withoutShifts > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$withoutShifts días de apertura sin turnos.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (!hasEligibleUsers)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Añade puestos y usuarios activos para poder generar el horario.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _working || !hasEligibleUsers
                  ? null
                  : () => _generateMonth(data),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generar mes'),
            ),
            OutlinedButton.icon(
              onPressed:
                  _working || draft == 0 ? null : () => _publishMonth(data),
              icon: const Icon(Icons.publish),
              label: const Text('Publicar'),
            ),
            TextButton.icon(
              onPressed: () => widget.onNavigate(HomeTab.shifts),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ver turnos'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _adminForecastCard(_HomeData data) {
    final result = data.forecast;
    final items = result?.items.take(3).toList() ?? const <Forecast>[];
    return _sectionCard(
      icon: Icons.insights,
      title: 'Previsión',
      subtitle: 'Apertura: ${_shortDate(data.nextOpen)}',
      action: TextButton(
        onPressed: () => widget.onNavigate(HomeTab.forecast),
        child: const Text('Ver previsión'),
      ),
      children: [
        if (items.isEmpty)
          _mutedText(
            result == null || result.recentNights == 0
                ? 'Aún no hay histórico suficiente para calcular la previsión.'
                : 'No hay productos con consumo registrado para esta noche.',
          )
        else ...[
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text(item.product.name)),
                  Text(
                    '${item.units} uds',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.boxes} cajas',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '${result!.items.length} productos · '
            '${result.recentNights} noches base',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  Widget _adminWarningsCard(_HomeData data) {
    final warnings = _adminWarnings(data);
    if (warnings.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return _sectionCard(
      icon: Icons.warning_amber_rounded,
      title: 'Avisos',
      children: [
        for (final warning in warnings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<String> _adminWarnings(_HomeData data) {
    final warnings = <String>[];
    final activeUsers = data.users.where((user) => user.active).toList();
    final withoutRole =
        activeUsers.where((user) => user.jobRole == null).length;
    if (withoutRole > 0) {
      warnings.add(
        '$withoutRole usuario${withoutRole == 1 ? '' : 's'} activo'
        '${withoutRole == 1 ? '' : 's'} sin puesto asignado.',
      );
    }

    final withoutShifts = _openDaysWithoutShifts(data);
    if (withoutShifts > 0) {
      warnings.add(
        '$withoutShifts día${withoutShifts == 1 ? '' : 's'} de apertura sin '
        'turnos este mes.',
      );
    }

    final forecast = data.forecast;
    if (forecast == null || forecast.recentNights == 0) {
      warnings.add(
        'Sin histórico suficiente para calcular la previsión.',
      );
    }
    return warnings;
  }

  // -------------------------------------------------------------------------
  // Empleado
  // -------------------------------------------------------------------------

  Widget _myShiftCard(_HomeData data, AppUser? user) {
    final theme = Theme.of(context);
    final next = data.myUpcoming.isEmpty ? null : data.myUpcoming.first;
    return _sectionCard(
      icon: Icons.event_available,
      title: 'Mi próximo turno',
      action: TextButton(
        onPressed: () => widget.onNavigate(HomeTab.shifts),
        child: const Text('Ver horario'),
      ),
      children: [
        if (next == null)
          _mutedText(
            data.mySchedulePending
                ? 'Tu horario está pendiente de publicación.'
                : 'No tienes turnos publicados.',
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  _longDate(DateTime.parse(next.date)),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _statusChip(next.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            next.timeLabel,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${next.roleName} · ${next.floor.label}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (data.myUpcoming.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Tienes ${data.myUpcoming.length - 1} turnos más publicados.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _myHoursCard(_HomeData data, AppUser? user) {
    final theme = Theme.of(context);
    final myShifts = data.monthShifts
        .where((shift) =>
            shift.userId == user?.id && shift.status != ShiftStatus.draft)
        .toList(growable: false);
    final total = myShifts.fold<int>(
      0,
      (sum, shift) => sum + shift.workedMinutes,
    );

    return _sectionCard(
      icon: Icons.schedule,
      title: 'Mis horas de ${_monthLabel(data.month)}',
      children: [
        if (myShifts.isEmpty)
          _mutedText('Aún no hay turnos publicados este mes.')
        else
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatHours(total),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${myShifts.length} turnos publicados o confirmados',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.timer_outlined,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
      ],
    );
  }

  Widget _employeeTonightCard(_HomeData data) {
    final visible = data.focusShifts
        .where((shift) => shift.status != ShiftStatus.draft)
        .toList(growable: false);
    return _sectionCard(
      icon: Icons.groups,
      title: data.focusIsTonight
          ? 'Esta noche en el bar'
          : 'Próxima noche en el bar',
      subtitle: _longDate(data.focusDay),
      children: [
        if (visible.isEmpty)
          _mutedText('Aún no hay turnos publicados para esa noche.')
        else
          for (final floor in Floor.values)
            _teamRow(
              floor: floor,
              shifts: visible.where((shift) => shift.floor == floor).toList(),
            ),
      ],
    );
  }

  Widget _employeeNoticeCard(_HomeData data) {
    if (!data.mySchedulePending) return const SizedBox.shrink();
    return _sectionCard(
      icon: Icons.info_outline,
      title: 'Aviso',
      children: [
        _mutedText(
          'Tu horario está pendiente de publicación. Cuando el encargado lo '
          'publique, aparecerá en Inicio y en Turnos.',
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Piezas compartidas
  // -------------------------------------------------------------------------

  Widget _stat(String value, String label, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamRow({
    required Floor floor,
    required List<Shift> shifts,
    String? warning,
    bool showStatus = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _floorIcon(floor),
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        floor.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (shifts.isNotEmpty)
                      Text(
                        '${shifts.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                if (shifts.isEmpty)
                  Text(
                    'Sin turnos',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    shifts.map((shift) => shift.userName).join(', '),
                    style: theme.textTheme.bodyMedium,
                  ),
                if (showStatus &&
                    shifts.any((s) => s.status == ShiftStatus.draft))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${shifts.where((s) => s.status == ShiftStatus.draft).length} '
                      'en borrador',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (warning != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      warning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(ShiftStatus status) {
    final theme = Theme.of(context);
    final color = switch (status) {
      ShiftStatus.draft => theme.colorScheme.onSurfaceVariant,
      ShiftStatus.published => theme.colorScheme.primary,
      ShiftStatus.confirmed => theme.colorScheme.tertiary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  int _openDaysWithoutShifts(_HomeData data) {
    final dates = data.monthShifts.map((shift) => shift.date).toSet();
    final today = Schedule.day(data.now);
    final daysInMonth = DateTime(data.month.year, data.month.month + 1, 0).day;
    var count = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(data.month.year, data.month.month, day);
      // Los días pasados ya no se pueden corregir; interesan los próximos.
      if (date.isBefore(today)) continue;
      if (Schedule.isOpen(date, data.special) &&
          !dates.contains(Schedule.fmt(date))) {
        count++;
      }
    }
    return count;
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el Inicio.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
