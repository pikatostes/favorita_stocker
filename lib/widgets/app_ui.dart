import 'package:flutter/material.dart';

/// Tarjeta de sección con un icono y un título, seguida de su contenido.
class AppSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const AppSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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

  const MutedText(this.text, {super.key, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: textAlign,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Línea de aviso con el icono y el color de error del tema.
class WarningLine extends StatelessWidget {
  final String text;

  const WarningLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: theme.colorScheme.error,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dato numérico con etiqueta, para mostrar en una fila de estadísticas.
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

/// Fila de estadísticas con columnas del mismo ancho.
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
                    fontWeight: FontWeight.bold,
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

/// Muestra un [SnackBar] con [text].
void showAppSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
