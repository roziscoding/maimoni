import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tailwind's neutral scale, which the web theme (Nuxt UI) is built on.
abstract final class Neutral {
  static const n50 = Color(0xFFFAFAFA);
  static const n100 = Color(0xFFF5F5F5);
  static const n200 = Color(0xFFE5E5E5);
  static const n300 = Color(0xFFD4D4D4);
  static const n400 = Color(0xFFA3A3A3);
  static const n500 = Color(0xFF737373);
  static const n600 = Color(0xFF525252);
  static const n700 = Color(0xFF404040);
  static const n800 = Color(0xFF262626);
  static const n900 = Color(0xFF171717);
  static const n950 = Color(0xFF0A0A0A);
}

/// Semantic colors for each mode, named like the web's tokens (`bg-elevated`, `text-muted`, ...)
/// so the two clients share one palette.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.bgMuted,
    required this.bgElevated,
    required this.bgAccented,
    required this.bgInverted,
    required this.text,
    required this.highlighted,
    required this.toned,
    required this.muted,
    required this.dimmed,
    required this.border,
    required this.borderAccented,
    required this.success,
    required this.error,
    required this.warning,
  });

  static const light = Palette(
    bg: Colors.white,
    bgMuted: Neutral.n100,
    bgElevated: Neutral.n100,
    bgAccented: Neutral.n200,
    bgInverted: Neutral.n900,
    text: Neutral.n900,
    highlighted: Neutral.n950,
    toned: Neutral.n600,
    muted: Neutral.n500,
    dimmed: Neutral.n400,
    border: Neutral.n200,
    borderAccented: Neutral.n300,
    success: Color(0xFF16A34A),
    error: Color(0xFFEF4444),
    warning: Color(0xFFCA8A04),
  );

  static const dark = Palette(
    bg: Neutral.n950,
    bgMuted: Neutral.n900,
    bgElevated: Neutral.n900,
    bgAccented: Neutral.n800,
    bgInverted: Colors.white,
    text: Neutral.n100,
    highlighted: Neutral.n50,
    toned: Neutral.n300,
    muted: Neutral.n400,
    dimmed: Neutral.n500,
    border: Neutral.n800,
    borderAccented: Neutral.n700,
    success: Color(0xFF4ADE80),
    error: Color(0xFFF87171),
    warning: Color(0xFFFACC15),
  );

  final Color bg;
  final Color bgMuted;
  final Color bgElevated;
  final Color bgAccented;
  final Color bgInverted;
  final Color text;
  final Color highlighted;
  final Color toned;
  final Color muted;
  final Color dimmed;
  final Color border;
  final Color borderAccented;
  final Color success;
  final Color error;
  final Color warning;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < 0.5 || other == null ? this : other;
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

/// Every money figure is set in the mono face with tabular digits so columns line up.
TextStyle money({double? fontSize, FontWeight? fontWeight, Color? color, double? height}) => GoogleFonts.geistMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: -0.01 * (fontSize ?? 14),
      fontFeatures: const [FontFeature.tabularFigures(), FontFeature.slashedZero()],
    );

ThemeData buildTheme(Brightness brightness) {
  final palette = brightness == Brightness.light ? Palette.light : Palette.dark;
  final primary = brightness == Brightness.light ? Colors.black : Colors.white;
  final onPrimary = brightness == Brightness.light ? Colors.white : Colors.black;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    secondary: palette.toned,
    onSecondary: palette.bg,
    error: palette.error,
    onError: Colors.white,
    surface: palette.bg,
    onSurface: palette.text,
    onSurfaceVariant: palette.muted,
    surfaceContainerLowest: palette.bg,
    surfaceContainerLow: palette.bg,
    surfaceContainer: palette.bgElevated,
    surfaceContainerHigh: palette.bgElevated,
    surfaceContainerHighest: palette.bgAccented,
    outline: palette.borderAccented,
    outlineVariant: palette.border,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final radius = BorderRadius.circular(12);
  // Every button is at least a finger tall.
  const buttonSize = Size(64, 48);
  const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: color, width: width));

  return base.copyWith(
    scaffoldBackgroundColor: palette.bg,
    extensions: [palette],
    // google_fonts' `interTextTheme` is typed against `package:material_ui`, so apply the family instead.
    textTheme: base.textTheme.apply(fontFamily: GoogleFonts.inter().fontFamily, bodyColor: palette.text, displayColor: palette.highlighted),
    dividerTheme: DividerThemeData(color: palette.border, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: palette.highlighted,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: palette.highlighted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: palette.bgAccented,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(size: 22, color: states.contains(WidgetState.selected) ? palette.highlighted : palette.muted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.inter(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? palette.highlighted : palette.muted,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: palette.highlighted,
      unselectedLabelColor: palette.muted,
      indicatorColor: primary,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: palette.border,
      labelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 3,
      highlightElevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      extendedTextStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.bgElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: palette.dimmed),
      border: border(palette.borderAccented),
      enabledBorder: border(palette.borderAccented),
      focusedBorder: border(primary, 2),
      errorBorder: border(palette.error),
      focusedErrorBorder: border(palette.error, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        foregroundColor: palette.text,
        side: BorderSide(color: palette.borderAccented),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: buttonSize,
        foregroundColor: palette.text,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: buttonText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: palette.muted)),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: palette.borderAccented,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: palette.border)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.bg,
      contentTextStyle: TextStyle(color: palette.text),
      actionTextColor: palette.highlighted,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: palette.border)),
      elevation: 4,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: palette.borderAccented, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      // Off, the thumb has to stand out from a track that is close to the background.
      thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? onPrimary : palette.muted),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? primary : palette.bgAccented,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary, linearTrackColor: palette.bgAccented),
    listTileTheme: ListTileThemeData(
      minTileHeight: 56,
      iconColor: palette.muted,
      titleTextStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: palette.highlighted),
      subtitleTextStyle: GoogleFonts.inter(fontSize: 13, color: palette.muted),
    ),
  );
}
