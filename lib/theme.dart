import 'package:flutter/material.dart';

/// Paleta de marca de La Favorita.
///
/// - [azulElectrico]: color principal (botones, enlaces, navegación activa).
/// - [ambarDorado]: acento (indicadores, selección, gráficos y detalles).
/// - [marronCarbon]: fondos oscuros, menús, encabezados y texto de contraste.
/// - [maderaTostada]: secundario cálido (detalles, iconos y decoración).
/// - [verdePetroleo]: paneles secundarios y estados activos.
/// - [beigeMadera]: fondos cálidos, bordes suaves y superficies de apoyo.
abstract final class AppColors {
  static const Color azulElectrico = Color(0xFF0576BA);
  static const Color ambarDorado = Color(0xFFE89E13);
  static const Color marronCarbon = Color(0xFF2C201D);
  static const Color maderaTostada = Color(0xFF804C1E);
  static const Color verdePetroleo = Color(0xFF193E46);
  static const Color beigeMadera = Color(0xFFC8AB92);

  /// Tinta clara usada como texto sobre fondos oscuros.
  static const Color tintaClara = Color(0xFFEFE3D6);
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
    lightSurface: const Color(0xFFF8F2EA),
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
    darkSurface: const Color(0xFF211815),
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
  static final List<AppPalette> all = [favorita, petroleo, madera, carbon, ambar];

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

  Color container(Color c) => _mix(c, surface, isDark ? 0.28 : 0.16);
  Color onContainer(Color c) => isDark ? _lighten(c, 0.75) : _darken(c, 0.55);

  final rampColor = isDark ? Colors.white : ink;
  final rampAmounts =
      isDark ? const [0.045, 0.075, 0.11, 0.15, 0.2] : const [0.0, 0.03, 0.06, 0.09, 0.12];

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
    onSurfaceVariant: _mix(ink, surface, 0.7),
    surfaceContainerLowest: isDark
        ? _mix(Colors.black, surface, 0.2)
        : _mix(Colors.white, surface, 0.55),
    surfaceContainerLow: _mix(rampColor, surface, rampAmounts[1]),
    surfaceContainer: _mix(rampColor, surface, rampAmounts[2]),
    surfaceContainerHigh: _mix(rampColor, surface, rampAmounts[3]),
    surfaceContainerHighest: _mix(rampColor, surface, rampAmounts[4]),
    outline: _mix(ink, surface, isDark ? 0.45 : 0.42),
    outlineVariant: _mix(ink, surface, isDark ? 0.22 : 0.18),
    inverseSurface: ink,
    onInverseSurface: surface,
    inversePrimary: isDark ? primary : _lighten(primary, 0.35),
  );
}

/// Base común a los dos modos: encabezados planos y elementos interactivos
/// (navegación, progreso, chips) tomando el color principal y el acento.
ThemeData _themeFrom(ColorScheme scheme) => ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.primary,
        elevation: 0,
        scrolledUnderElevation: 3,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      chipTheme: ChipThemeData(
        selectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
      ),
    );

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
