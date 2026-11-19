import 'package:flutter/material.dart';

import '../../../app_design.dart';
import '../../../data/home_data.dart';
import '../../../formats.dart';
import '../../../schedule.dart';
import '../../../shifts.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/user_avatar.dart';

/// Cabecera del Inicio con el saludo, el estado del bar y la próxima excepción
/// del calendario. Mantiene el logotipo reconocible sin que domine la pantalla.
class HomeHeader extends StatelessWidget {
  final HomeData data;
  final AppUser? user;

  const HomeHeader({super.key, required this.data, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = user?.role == UserRole.admin;
    final rawName =
        user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'equipo';
    final name = rawName.split(RegExp(r'\s+')).first;
    final status = _statusFor(data);

    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hola, $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          formatLongDate(data.now),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final avatar = Tooltip(
      message: user?.fullName ?? 'Cuenta',
      child: UserAvatar(
        user: user,
        radius: 20,
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        foregroundColor: theme.colorScheme.onSurface,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppLogo(height: 26),
                        const Spacer(),
                        avatar,
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    greeting,
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(
                          label: status.label,
                          icon: status.icon,
                          tone: status.tone,
                        ),
                        Text(
                          status.detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppLogo(height: 30),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: greeting),
                  const SizedBox(width: AppSpacing.lg),
                  StatusPill(
                    label: status.label,
                    icon: status.icon,
                    tone: status.tone,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    status.detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  avatar,
                ],
              );
            },
          ),
          if (isAdmin) _NextSpecialLine(data: data),
        ],
      ),
    );
  }
}

class _HomeStatus {
  final String label;
  final String detail;
  final IconData icon;
  final AppTone tone;

  const _HomeStatus({
    required this.label,
    required this.detail,
    required this.icon,
    required this.tone,
  });
}

_HomeStatus _statusFor(HomeData data) {
  if (data.openNow) {
    return _HomeStatus(
      label: 'Abierto ahora',
      detail: 'Servicio ${formatShortDate(data.serviceDay)}',
      icon: Icons.nightlife,
      tone: AppTone.success,
    );
  }
  if (data.opensLaterToday) {
    return _HomeStatus(
      label: 'Abre esta noche',
      detail: formatShortDate(data.nextOpen),
      icon: Icons.schedule,
      tone: AppTone.warning,
    );
  }
  return _HomeStatus(
    label: 'Cerrado',
    detail: 'Próxima apertura ${formatShortDate(data.nextOpen)}',
    icon: Icons.nightlight_round,
    tone: AppTone.neutral,
  );
}

class _NextSpecialLine extends StatelessWidget {
  final HomeData data;

  const _NextSpecialLine({required this.data});

  @override
  Widget build(BuildContext context) {
    final label = _nextSpecialLabel(data);
    if (label == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.event_outlined,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _nextSpecialLabel(HomeData data) {
  final todayKey = Schedule.fmt(Schedule.day(data.now));
  final upcoming = data.special.entries
      .where((entry) => entry.key.compareTo(todayKey) >= 0)
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  if (upcoming.isEmpty) return null;
  final entry = upcoming.first;
  final note = entry.value.note.trim();
  final action = entry.value.open ? 'apertura' : 'cierre';
  return 'Calendario: ${formatShortDateIso(entry.key)} · $action'
      '${note.isEmpty ? '' : ' · $note'}';
}
