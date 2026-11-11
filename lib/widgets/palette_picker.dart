import 'package:flutter/material.dart';

import '../app_design.dart';
import '../theme.dart';

/// Abre la hoja de selección de paletas.
///
/// Al elegir una, se actualiza [selectedPalette]; `main.dart` escucha ese
/// notificador y reconstruye el `MaterialApp` con el tema correspondiente.
Future<void> showPalettePicker(BuildContext context) async {
  final current = selectedPalette.value;
  final chosen = await showModalBottomSheet<AppPalette>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Paleta de colores',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final palette in AppPalettes.all)
            ListTile(
              selected: palette.id == current.id,
              leading: PaletteSwatch(palette: palette),
              title: Text(palette.name),
              subtitle: Text(palette.description),
              trailing: palette.id == current.id
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(context, palette),
            ),
        ],
      ),
    ),
  );
  if (chosen != null) selectedPalette.value = chosen;
}

/// Círculo con los tres colores principales de una paleta.
class PaletteSwatch extends StatelessWidget {
  final AppPalette palette;
  final double size;

  const PaletteSwatch({super.key, required this.palette, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final scheme = palette.light.colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

/// Botón compacto para abrir el selector de paletas desde una barra de
/// acciones. Con [withLabel] se muestra como botón con texto.
class PaletteButton extends StatelessWidget {
  final bool withLabel;

  const PaletteButton({super.key, this.withLabel = false});

  @override
  Widget build(BuildContext context) {
    if (withLabel) {
      return OutlinedButton.icon(
        onPressed: () => showPalettePicker(context),
        icon: const Icon(Icons.palette_outlined),
        label: const Text('Paleta de colores'),
      );
    }
    return IconButton(
      tooltip: 'Paleta de colores',
      icon: const Icon(Icons.palette_outlined),
      onPressed: () => showPalettePicker(context),
    );
  }
}

/// Fila de ajuste con la paleta activa y acceso al selector.
///
/// Pensada para la tarjeta de opciones de Cuenta: muestra el nombre actual y
/// se refresca sola cuando cambia [selectedPalette].
class PaletteTile extends StatelessWidget {
  const PaletteTile({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppPalette>(
        valueListenable: selectedPalette,
        builder: (context, current, _) => ListTile(
          leading: PaletteSwatch(palette: current),
          title: const Text('Paleta de colores'),
          subtitle: Text(current.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showPalettePicker(context),
        ),
      );
}
