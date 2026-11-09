import 'package:flutter/material.dart';

import '../app_design.dart';

/// Tarjeta de sección con un icono y un título, seguida de su contenido.
class AppSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final bool dense;

  const AppSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.margin = EdgeInsets.zero,
    this.trailing,
    this.padding,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gap = dense ? AppSpacing.sm : AppSpacing.md;
    return Card(
      margin: margin,
      child: Padding(
        padding: padding ??
            EdgeInsets.fromLTRB(
              dense ? AppSpacing.md : AppSpacing.lg,
              dense ? AppSpacing.md : AppSpacing.lg,
              dense ? AppSpacing.md : AppSpacing.lg,
              dense ? AppSpacing.md : AppSpacing.lg,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: dense ? 26 : 30,
                  height: dense ? 26 : 30,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(
                    icon,
                    size: dense ? 16 : 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: (dense
                              ? theme.textTheme.titleSmall
                              : theme.textTheme.titleMedium)
                          ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),
            SizedBox(height: gap),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Texto secundario y atenuado.
class MutedText extends StatelessWidget {
  final String text;
  final TextAlign textAlign;
  final int? maxLines;

  const MutedText(
    this.text, {
    super.key,
    this.textAlign = TextAlign.start,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Línea de aviso con el icono y el color de advertencia del sistema.
class WarningLine extends StatelessWidget {
  final String text;

  const WarningLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      AlertBanner(message: text, tone: AppTone.warning, dense: true);
}

/// Píldora de estado reutilizable (abierto, cerrado, borrador, etc.).
class StatusPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final AppTone tone;
  final bool dense;

  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = AppTone.neutral,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appToneColors(context, tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: colors.foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense
                      ? theme.textTheme.labelSmall
                      : theme.textTheme.labelMedium)
                  ?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso o alerta con fondo tonal y acción opcional.
class AlertBanner extends StatelessWidget {
  final String message;
  final String? title;
  final IconData? icon;
  final AppTone tone;
  final bool dense;
  final Widget? action;

  const AlertBanner({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.tone = AppTone.info,
    this.dense = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appToneColors(context, tone);
    final fallbackIcon = switch (tone) {
      AppTone.success => Icons.check_circle_outline,
      AppTone.warning => Icons.warning_amber_rounded,
      AppTone.danger => Icons.error_outline,
      AppTone.info => Icons.info_outline,
      AppTone.neutral => Icons.circle_outlined,
    };
    return Container(
      padding: EdgeInsets.all(dense ? 10 : AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? fallbackIcon,
            size: dense ? 16 : 19,
            color: colors.foreground,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      title!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  message,
                  style: (dense
                          ? theme.textTheme.bodySmall
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(color: colors.foreground),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Dato destacado con etiqueta e icono. Se usa en dashboards y resúmenes.
class AppStatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final AppTone tone;
  final String? hint;
  final bool dense;

  const AppStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.tone = AppTone.neutral,
    this.hint,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appToneColors(context, tone);
    return Container(
      padding: EdgeInsets.all(dense ? 10 : AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: tone == AppTone.neutral
              ? theme.colorScheme.outlineVariant
              : colors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: dense ? 14 : 16, color: colors.foreground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (dense
                          ? theme.textTheme.labelSmall
                          : theme.textTheme.labelMedium)
                      ?.copyWith(color: colors.foreground),
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 4 : 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (dense
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.headlineSmall)
                ?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              maxLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.foreground.withValues(alpha: 0.82),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila de estadísticas con columnas del mismo ancho. Se conserva para usos
/// sencillos; [AppStatTile] ofrece más jerarquía visual.
class AppStat {
  final String value;
  final String label;
  final Color color;

  const AppStat({
    required this.value,
    required this.label,
    required this.color,
  });
}

class AppStatsRow extends StatelessWidget {
  final List<AppStat> stats;

  const AppStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final stat in stats)
          Expanded(
            child: Column(
              children: [
                Text(
                  stat.value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: stat.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  stat.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Cabecera de pantalla que se adapta al ancho: título, subtítulo y acciones.
///
/// En móvil las acciones pasan a una fila aparte para evitar que el título se
/// comprima o que aparezcan botones sin contexto.
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? leading;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.leading,
    this.actions = const [],
    this.padding = EdgeInsets.zero,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleBlock = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    eyebrow!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = actions.isNotEmpty &&
              (constraints.maxWidth < 720 || actions.length > 3);
          if (actions.isEmpty) return titleBlock;
          final actionWrap = Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleBlock,
                const SizedBox(height: AppSpacing.md),
                actionWrap,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: AppSpacing.lg),
              actionWrap,
            ],
          );
        },
      ),
    );
  }
}

/// Contenedor que limita el ancho de lectura en tablet/escritorio y centra el
/// contenido para que las tarjetas no se estiren de forma innecesaria.
class AppContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const AppContentFrame({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// Estado de carga con etiqueta opcional.
class AppLoadingState extends StatelessWidget {
  final String? label;

  const AppLoadingState({super.key, this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              if (label != null) ...[
                const SizedBox(height: AppSpacing.md),
                MutedText(label!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      );
}

/// Estado vacío compartido.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                MutedText(message!, textAlign: TextAlign.center),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado de error centrado, con un botón para volver a intentarlo.
class AppErrorState extends StatelessWidget {
  final String title;
  final Object error;
  final VoidCallback onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    this.title = 'No se pudo cargar el contenido.',
    required this.error,
    required this.onRetry,
    this.retryLabel = 'Reintentar',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 26,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Muestra un [SnackBar] con [text] y el tono semántico indicado.
void showAppSnack(
  BuildContext context,
  String text, {
  AppTone tone = AppTone.neutral,
}) {
  final colors = appToneColors(context, tone);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              switch (tone) {
                AppTone.success => Icons.check_circle_outline,
                AppTone.warning => Icons.warning_amber_rounded,
                AppTone.danger => Icons.error_outline,
                AppTone.info => Icons.info_outline,
                AppTone.neutral => Icons.notifications_none,
              },
              size: 20,
              color: colors.foreground,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.foreground,
                    ),
              ),
            ),
          ],
        ),
        backgroundColor: colors.background,
        action: SnackBarAction(
          label: 'Cerrar',
          textColor: colors.foreground,
          onPressed: () {},
        ),
      ),
    );
}

/// Diálogo de confirmación simple. Devuelve `true` si se confirma.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Continuar',
  String cancelLabel = 'Cancelar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
