import 'package:flutter/material.dart';

import '../../app_design.dart';
import '../../auth_controller.dart';
import '../../db.dart';
import '../../formats.dart';
import '../../shifts.dart';
import '../../widgets/app_ui.dart';
import '../plan.dart';
import 'home_cards.dart';
import 'home_data.dart';

/// Panel de Inicio: carga los datos y compone las tarjetas según el rol.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  late Future<HomeData> _future = loadHomeData();
  bool _working = false;

  void _reload() {
    if (mounted) setState(() => _future = loadHomeData());
  }

  Future<void> _refresh() async {
    final future = loadHomeData();
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

  Future<void> _generateMonth(HomeData data) async {
    if (_working) return;
    if (!data.hasEligibleUsers) {
      showAppSnack(
        context,
        'Añade puestos y usuarios activos para poder generar el horario.',
        tone: AppTone.warning,
      );
      return;
    }
    final month = DateTime(data.now.year, data.now.month);
    if (data.monthShifts.isNotEmpty) {
      final ok = await showConfirmDialog(
        context,
        title: 'Regenerar ${formatMonthLabel(month)}',
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
      showAppSnack(context, 'Generados $count turnos.', tone: AppTone.success);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudo generar el horario: $error',
        tone: AppTone.danger,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _publishMonth(HomeData data) async {
    if (_working) return;
    final drafts = data.countShifts(ShiftStatus.draft);
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

    setState(() => _working = true);
    try {
      await Db.i.publishMonth(month);
      if (!mounted) return;
      showAppSnack(context, 'Turnos publicados.', tone: AppTone.success);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(
        context,
        'No se pudieron publicar los turnos: $error',
        tone: AppTone.danger,
      );
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
        final user = AuthController.i.user;
        final isAdmin = user?.role == UserRole.admin;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= AppBreakpoints.twoColumnContent;
              final horizontal =
                  constraints.maxWidth >= AppBreakpoints.desktopMin
                      ? AppSpacing.xl
                      : constraints.maxWidth >= AppBreakpoints.tabletMin
                          ? AppSpacing.xl
                          : AppSpacing.lg;
              final padding = EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.lg,
                horizontal,
                AppSpacing.xl,
              );

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  AppContentFrame(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HomeHeader(data: data, user: user),
                        if (user?.isMaintenance == true) ...[
                          MaintenanceListCard(
                            data: data,
                            onOpen: _openNightPlan,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (isAdmin)
                          wide
                              ? _WideColumns(
                                  left: AdminTonightCard(data: data),
                                  right: AdminPlanningCard(
                                    data: data,
                                    working: _working,
                                    onGenerate: () => _generateMonth(data),
                                    onPublish: () => _publishMonth(data),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AdminTonightCard(data: data),
                                    const SizedBox(height: AppSpacing.lg),
                                    AdminPlanningCard(
                                      data: data,
                                      working: _working,
                                      onGenerate: () => _generateMonth(data),
                                      onPublish: () => _publishMonth(data),
                                    ),
                                  ],
                                )
                        else
                          wide
                              ? _WideColumns(
                                  left: MyDayCard(data: data, user: user),
                                  right: EmployeeTonightCard(data: data),
                                  leftFlex: 2,
                                  rightFlex: 3,
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    MyDayCard(data: data, user: user),
                                    const SizedBox(height: AppSpacing.lg),
                                    EmployeeTonightCard(data: data),
                                  ],
                                ),
                        const SizedBox(height: AppSpacing.lg),
                        const IncidentsCard(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Dos columnas equilibradas para escritorio, con separación consistente.
class _WideColumns extends StatelessWidget {
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  const _WideColumns({
    required this.left,
    required this.right,
    this.leftFlex = 3,
    this.rightFlex = 2,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex, child: left),
          const SizedBox(width: AppSpacing.lg),
          Expanded(flex: rightFlex, child: right),
        ],
      );
}
