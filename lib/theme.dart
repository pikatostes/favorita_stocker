import 'package:flutter/material.dart';

import 'app_design.dart';

/// Paleta de marca de La Favorita.
///
/// - [azulElectrico]: color principal (acciones, selección y enlaces).
/// - [ambarDorado]: acento cálido (avisos, indicadores y detalles).
/// - [marronCarbon]: fondo oscuro de la aplicación.
/// - [maderaTostada]: secundario cálido.
/// - [verdePetroleo]: apoyo profundo.
/// - [beigeMadera]: superficies y bordes cálidos.
/// - [tintaClara]: texto principal sobre fondos oscuros.
abstract final class AppColors {
  static const Color azulElectrico = Color(0xFF0576BA);
  static const Color azulClaro = Color(0xFF7CC7F0);
  static const Color ambarDorado = Color(0xFFE89E13);
  static const Color marronCarbon = Color(0xFF2C201D);
  static const Color marronProfundo = Color(0xFF211714);
  static const Color maderaTostada = Color(0xFF804C1E);
  static const Color verdePetroleo = Color(0xFF193E46);
  static const Color beigeMadera = Color(0xFFC8AB92);
  static const Color tintaClara = Color(0xFFEFE3D6);
  static const Color grisCalido = Color(0xFFC7B9AB);
  static const Color cremaClara = Color(0xFFF8F2EA);
}

/// Un tema concreto para comparar: agrupa la versión clara y la oscura de una
/// misma combinación de la paleta.
class AppPalette {
  final String id;
  final String name;
  final String description;
  final ThemeData light;
  final ThemeData dark;

  const AppPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.light,
    required this.dark,
  });
}

/// Catálogo de propuestas de tema. Todas usan los seis colores de la paleta,
/// pero reparten los roles (principal, acento, secundario y fondos) de distinta
/// forma para poder compararlas en la aplicación real.
abstract final class AppPalettes {
  /// Azul eléctrico como protagonista, ámbar de acento. Es la opción base.
  static final AppPalette favorita = _make(
    id: 'favorita',
    name: 'Favorita (azul)',
    description: 'Azul eléctrico principal, ámbar de acento y beige cálido.',
    primary: AppColors.azulElectrico,
    secondary: AppColors.ambarDorado,
    tertiary: AppColors.maderaTostada,
    lightSurface: AppColors.cremaClara,
    darkSurface: AppColors.marronCarbon,
  );

  /// Verde petróleo dominante, sensación más sobria y profunda.
  static final AppPalette petroleo = _make(
    id: 'petroleo',
    name: 'Petróleo',
    description: 'Verde petróleo dominante con acentos ámbar y beige.',
    primary: AppColors.verdePetroleo,
    secondary: AppColors.ambarDorado,
    tertiary: AppColors.beigeMadera,
    lightSurface: const Color(0xFFF1EFE7),
    darkSurface: const Color(0xFF142F36),
  );

  /// Madera tostada y ámbar: la propuesta más cálida y rústica.
  static final AppPalette madera = _make(
    id: 'madera',
    name: 'Madera',
    description: 'Marrón tostado cálido con ámbar y azul de apoyo.',
    primary: AppColors.maderaTostada,
    secondary: AppColors.ambarDorado,
    tertiary: AppColors.azulElectrico,
    lightSurface: const Color(0xFFF7EFE3),
    darkSurface: AppColors.marronCarbon,
  );

  /// Marrón carbón sobrio, elegante, con ámbar y azul como acentos.
  static final AppPalette carbon = _make(
    id: 'carbon',
    name: 'Carbón',
    description: 'Base marrón carbón sobria con ámbar y azul de acento.',
    primary: AppColors.marronCarbon,
    secondary: AppColors.ambarDorado,
    tertiary: AppColors.azulElectrico,
    lightSurface: const Color(0xFFEFE7DB),
    darkSurface: AppColors.marronProfundo,
  );

  /// Ámbar dorado protagonista: la opción más viva y cálida.
  static final AppPalette ambar = _make(
    id: 'ambar',
    name: 'Ámbar',
    description: 'Ámbar dorado protagonista con azul y petróleo de apoyo.',
    primary: AppColors.ambarDorado,
    secondary: AppColors.azulElectrico,
    tertiary: AppColors.verdePetroleo,
    lightSurface: const Color(0xFFFAF3E4),
    darkSurface: AppColors.marronCarbon,
  );

  /// Todas las propuestas, en el orden en que se muestran.
  static final List<AppPalette> all = [
    favorita,
    petroleo,
    madera,
    carbon,
    ambar
  ];

  static AppPalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => favorita);
}

/// Paleta seleccionada en tiempo de ejecución. La UI escucha este notificador
/// (ver `main.dart`) para reconstruir el `MaterialApp` al cambiar de tema.
final ValueNotifier<AppPalette> selectedPalette =
    ValueNotifier<AppPalette>(AppPalettes.favorita);

/// Construye una propuesta a partir de los roles de la paleta.
AppPalette _make({
  required String id,
  required String name,
  required String description,
  required Color primary,
  required Color secondary,
  required Color tertiary,
  required Color lightSurface,
  required Color darkSurface,
}) {
  return AppPalette(
    id: id,
    name: name,
    description: description,
    light: _themeFrom(_scheme(
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: lightSurface,
      ink: AppColors.marronCarbon,
    )),
    dark: _themeFrom(_scheme(
      brightness: Brightness.dark,
      primary: _legibleOnDark(primary),
      secondary: _legibleOnDark(secondary),
      tertiary: _legibleOnDark(tertiary),
      surface: darkSurface,
      ink: AppColors.tintaClara,
    )),
  );
}

/// Arma un `ColorScheme` completo a partir de los colores de marca, derivando
/// contenedores, contornos y la escala de superficies.
ColorScheme _scheme({
  required Brightness brightness,
  required Color primary,
  required Color secondary,
  required Color tertiary,
  required Color surface,
  required Color ink,
}) {
  final isDark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: primary, brightness: brightness);

  Color container(Color c) => _mix(c, surface, isDark ? 0.24 : 0.14);
  Color onContainer(Color c) => isDark ? _lighten(c, 0.78) : _darken(c, 0.55);

  final rampColor = isDark ? Colors.white : AppColors.marronCarbon;
  final rampAmounts = isDark
      ? const [0.035, 0.065, 0.10, 0.145, 0.19]
      : const [0.0, 0.025, 0.05, 0.08, 0.11];

  return base.copyWith(
    primary: primary,
    onPrimary: _onColor(primary),
    primaryContainer: container(primary),
    onPrimaryContainer: onContainer(primary),
    secondary: secondary,
    onSecondary: _onColor(secondary),
    secondaryContainer: container(secondary),
    onSecondaryContainer: onContainer(secondary),
    tertiary: tertiary,
    onTertiary: _onColor(tertiary),
    tertiaryContainer: container(tertiary),
    onTertiaryContainer: onContainer(tertiary),
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: isDark
        ? _mix(AppColors.grisCalido, surface, 0.82)
        : _mix(ink, surface, 0.62),
    surfaceContainerLowest: isDark
        ? _mix(Colors.black, surface, 0.22)
        : _mix(Colors.white, surface, 0.64),
    surfaceContainerLow: _mix(rampColor, surface, rampAmounts[1]),
    surfaceContainer: _mix(rampColor, surface, rampAmounts[2]),
    surfaceContainerHigh: _mix(rampColor, surface, rampAmounts[3]),
    surfaceContainerHighest: _mix(rampColor, surface, rampAmounts[4]),
    outline: _mix(ink, surface, isDark ? 0.42 : 0.40),
    outlineVariant: _mix(ink, surface, isDark ? 0.20 : 0.16),
    inverseSurface: ink,
    onInverseSurface: surface,
    inversePrimary: isDark ? primary : _lighten(primary, 0.35),
    error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
    onError: isDark ? const Color(0xFF690005) : Colors.white,
    errorContainer: isDark ? const Color(0xFF5A1A19) : const Color(0xFFF9DEDC),
    onErrorContainer:
        isDark ? const Color(0xFFFFDAD6) : const Color(0xFF410E0B),
    surfaceTint: Colors.transparent,
  );
}

/// Base común a los dos modos: superficies cálidas, tipografía compacta y
/// controles interactivos con áreas táctiles cómodas.
ThemeData _themeFrom(ColorScheme scheme) {
  final isDark = scheme.brightness == Brightness.dark;
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: scheme.brightness,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );

  final textTheme = base.textTheme.copyWith(
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      height: 1.15,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.18,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.2,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.4),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.35),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
  );

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.lg),
    side: BorderSide(
      color: scheme.outlineVariant.withValues(alpha: isDark ? 0.55 : 0.7),
    ),
  );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    disabledColor: scheme.onSurface.withValues(alpha: 0.38),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: cardShape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: buttonShape,
        side: BorderSide(color: scheme.outline),
        textStyle: textTheme.labelLarge,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.square(44)),
        tapTargetSize: MaterialTapTargetSize.padded,
        iconSize: const WidgetStatePropertyAll(20),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      floatingLabelStyle: textTheme.bodySmall?.copyWith(color: scheme.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: AppBreakpoints.bottomBarHeight,
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
      unselectedIconTheme:
          IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelMedium,
      overlayColor: WidgetStatePropertyAll(
        scheme.primary.withValues(alpha: 0.08),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.secondaryContainer,
      disabledColor: scheme.surfaceContainer,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onSecondaryContainer,
      ),
      checkmarkColor: scheme.onSecondaryContainer,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: scheme.surfaceContainerLow,
      modalBarrierColor: Colors.black.withValues(alpha: 0.55),
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      minVerticalPadding: 10,
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
      subtitleTextStyle:
          textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      textStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
        textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHighest,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(
        scheme.onSurfaceVariant.withValues(alpha: 0.45),
      ),
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(AppRadii.pill),
    ),
    extensions: [
      isDark ? AppSemanticColors.dark : AppSemanticColors.light,
    ],
  );
}

/// Mezcla [foreground] sobre [background] con la opacidad [amount].
Color _mix(Color foreground, Color background, double amount) =>
    Color.alphaBlend(foreground.withValues(alpha: amount), background);

Color _darken(Color color, double amount) =>
    Color.alphaBlend(Colors.black.withValues(alpha: amount), color);

Color _lighten(Color color, double amount) =>
    Color.alphaBlend(Colors.white.withValues(alpha: amount), color);

/// Color de texto/icono legible sobre [background].
Color _onColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : AppColors.marronCarbon;

/// En modo oscuro un color de marca demasiado oscuro pierde contraste: se
/// aclara hasta que destaque sobre el fondo.
Color _legibleOnDark(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? _lighten(color, 0.45)
        : color;
