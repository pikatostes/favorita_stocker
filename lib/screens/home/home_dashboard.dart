import 'package:flutter/material.dart';

import '../../app_design.dart';
import '../../auth_controller.dart';
import '../../data/home_data.dart';
import '../../data/home_repository.dart';
import '../../db.dart';
import '../../formats.dart';
import '../../widgets/app_ui.dart';
import '../plan.dart';
import '../turnos/schedule/plan_config_dialog.dart';
import 'home_content.dart';

/// Panel de Inicio.
///
/// Mantiene la carga, el refresco y las acciones de planificación. La
/// composición visual vive en [HomeContent] y cada tarjeta en su propio
/// archivo, dentro de `screens/home/widgets/`.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  late Future<HomeData> _future = HomeRepository.i.load();
  late final VoidCallback _stopWatching;
  bool _working = false;

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = HomeRepository.i.load();
    });
  }

  Future<void> _refresh() async {
    Db.i.invalidateCache();
    final future = HomeRepository.i.load();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  void initState() {
    super.initState();
    _stopWatching = Db.i.watchTables(
      {
        'special_day',
        'shift',
        ...Db.userTables,
        ...Db.nightTables,
        ...Db.productTables,
      },
      _reload,
    );
    AuthController.i.addListener(_reload);
  }

  @override
  void dispose() {
    _stopWatching();
    AuthController.i.removeListener(_reload);
    super.dispose();
  }

  Future<void> _generateMonth(HomeData data) async {
    if (_working) return;
    if (!data.hasEligibleUsers) {
      showAppSnack(
        context,
        'Añade usuarios activos con puesto para poder generar el horario.',
        tone: AppTone.warning,
      );
      return;
    }
    final month = DateTime(data.now.year, data.now.month);
    final config = await showShiftPlanDialog(
      context,
      month: month,
      users: data.users,
      specialDays: data.special,
      existingShifts: data.monthShifts.length,
    );
    if (config == null || !mounted) return;

    await _runPlanning(
      action: () async {
        final count = await Db.i.generateMonthShifts(month, config: config);
        return 'Generados $count turnos.';
      },
      failure: 'No se pudo generar el horario',
    );
  }

  Future<void> _publishMonth(HomeData data) async {
    if (_working) return;
    final drafts = data.shiftCounts.drafts;
    if (drafts == 0) {
      showAppSnack(
        context,
        'No hay turnos en borrador para publicar.',
        tone: AppTone.warning,
      );
      return;
    }
    final month = DateTime(data.now.year, data.now.month);
    final ok = await showConfirmDialog(
      context,
      title: 'Publicar ${formatMonthLabel(month)}',
      message: 'Se publicarán $drafts turnos. Los empleados podrán verlos en '
          'su horario.',
      confirmLabel: 'Publicar',
    );
    if (!ok || !mounted) return;

    await _runPlanning(
      action: () async {
        await Db.i.publishMonth(month);
        return 'Turnos publicados.';
      },
      failure: 'No se pudieron publicar los turnos',
    );
  }

  /// Ejecuta una acción de planificación con el indicador de trabajo y el
  /// mismo tratamiento de errores. [action] devuelve el mensaje de éxito.
  Future<void> _runPlanning({
    required Future<String> Function() action,
    required String failure,
  }) async {
    setState(() => _working = true);
    try {
      final message = await action();
      if (!mounted) return;
      showAppSnack(context, message, tone: AppTone.success);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, '$failure: $error', tone: AppTone.danger);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openNightPlan(NightListSummary list) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlanScreen(
            qty: list.qty,
            fullBoxes: list.fullBoxes,
            title: 'Montar cajas',
            date: list.date,
            floor: list.floor,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppErrorState(
            title: 'No se pudo cargar el Inicio.',
            error: snapshot.error!,
            onRetry: _reload,
          );
        }
        if (!snapshot.hasData) {
          return const AppLoadingState(label: 'Cargando el panel…');
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: HomeContent(
            data: data,
            user: AuthController.i.user,
            working: _working,
            onGenerate: () => _generateMonth(data),
            onPublish: () => _publishMonth(data),
            onOpenPlan: _openNightPlan,
          ),
        );
      },
    );
  }
}
