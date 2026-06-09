import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Semantic colors — immutable, same values in both themes ───────────────────
class AppColors {
  AppColors._();

  // Primary — kept as compile-time constants for const widget constructors.
  // Dynamic callers should prefer context.colors.primary / primaryLight / accent.
  static const Color primary      = Color(0xFF3B44FF);
  static const Color primaryLight = Color(0xFF5874FF);
  static const Color accent       = Color(0xFF5874FF);

  // Semantic: main color (border/icon) + bg color (card fill)
  static const Color success      = Color(0xFF7DFF95);
  static const Color successBg    = Color(0xFFB8FFC1);

  static const Color warning      = Color(0xFFFFBC5E);
  static const Color warningBg    = Color(0xFFFFD8A4);

  static const Color danger       = Color(0xFFFF8080);
  static const Color dangerBg     = Color(0xFFFFB5B2);

  static const Color info         = Color(0xFF87D1FF);
  static const Color infoBg       = Color(0xFFB9E4FF);

}

// ── Structural + brand colors — available via context.colors ──────────────────
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    // Brand colours — dynamic, overridden per build from org settings
    this.primary      = AppColors.primary,
    this.primaryLight = AppColors.primaryLight,
    this.accent       = AppColors.accent,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primaryLight;
  final Color accent;

  // ── Dark palette ──────────────────────────────────────────────────────────
  static const dark = AppColorScheme(
    background:    Color(0xFF121212),
    surface:       Color(0xFF252525),
    card:          Color(0xFF252525),
    border:        Color(0xFF393939),
    textPrimary:   Color(0xFFFFFFFF),
    textSecondary: Color(0xFFC0C0C0),
    textMuted:     Color(0xFF888888),
  );

  // ── Light palette ─────────────────────────────────────────────────────────
  static const light = AppColorScheme(
    background:    Color(0xFFFFFFFF),
    surface:       Color(0xFFF2F2F2),
    card:          Color(0xFFF2F2F2),
    border:        Color(0xFFE4E4E4),
    textPrimary:   Color(0xFF000000),
    textSecondary: Color(0xFF444444),
    textMuted:     Color(0xFF777777),
  );

  @override
  AppColorScheme copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primary,
    Color? primaryLight,
    Color? accent,
  }) =>
      AppColorScheme(
        background:    background    ?? this.background,
        surface:       surface       ?? this.surface,
        card:          card          ?? this.card,
        border:        border        ?? this.border,
        textPrimary:   textPrimary   ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted:     textMuted     ?? this.textMuted,
        primary:       primary       ?? this.primary,
        primaryLight:  primaryLight  ?? this.primaryLight,
        accent:        accent        ?? this.accent,
      );

  @override
  AppColorScheme lerp(AppColorScheme? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      background:    Color.lerp(background,    other.background,    t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      card:          Color.lerp(card,          other.card,          t)!,
      border:        Color.lerp(border,        other.border,        t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:     Color.lerp(textMuted,     other.textMuted,     t)!,
      primary:       Color.lerp(primary,       other.primary,       t)!,
      primaryLight:  Color.lerp(primaryLight,  other.primaryLight,  t)!,
      accent:        Color.lerp(accent,        other.accent,        t)!,
    );
  }
}

// ── Convenience accessor ──────────────────────────────────────────────────────
extension BuildContextColors on BuildContext {
  AppColorScheme get colors => Theme.of(this).extension<AppColorScheme>()!;
}

// ── Themes ────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  /// Default blue — used when no org primary color has been configured yet.
  static const _defaultPrimary = AppColors.primary;

  static ThemeData darkTheme([Color primary = _defaultPrimary]) =>
      _build(AppColorScheme.dark,  Brightness.dark,  primary);
  static ThemeData lightTheme([Color primary = _defaultPrimary]) =>
      _build(AppColorScheme.light, Brightness.light, primary);

  /// Derives a lighter tint from [primary] for text links and nav highlights.
  static Color derivePrimaryLight(Color primary) =>
      Color.lerp(primary, Colors.white, 0.38)!;

  /// Derives the softest accent tint from [primary].
  static Color deriveAccent(Color primary) =>
      Color.lerp(primary, Colors.white, 0.52)!;

  static ThemeData _build(
      AppColorScheme base, Brightness brightness, Color primary) {
    final pLight = derivePrimaryLight(primary);
    final pAccent = deriveAccent(primary);
    final isDark  = brightness == Brightness.dark;

    // Inject dynamic brand colours into the scheme extension
    final c = base.copyWith(
      primary:      primary,
      primaryLight: pLight,
      accent:       pAccent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness:  brightness,
        primary:     primary,
        onPrimary:   Colors.white,
        secondary:   pAccent,
        onSecondary: Colors.white,
        error:       AppColors.danger,
        onError:     Colors.white,
        surface:     c.surface,
        onSurface:   c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: c.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pLight,
          side: BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(color: c.textSecondary),
        hintStyle: TextStyle(color: c.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dividerColor: c.border,
      dividerTheme: DividerThemeData(color: c.border),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: pLight,
        unselectedItemColor: c.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
      textTheme: GoogleFonts.interTextTheme(TextTheme(
        headlineLarge:  TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
        headlineSmall:  TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
        titleLarge:     TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
        titleMedium:    TextStyle(color: c.textPrimary, fontWeight: FontWeight.w500),
        titleSmall:     TextStyle(color: c.textSecondary),
        bodyLarge:      TextStyle(color: c.textPrimary),
        bodyMedium:     TextStyle(color: c.textSecondary),
        bodySmall:      TextStyle(color: c.textMuted),
        labelLarge:     TextStyle(color: c.textPrimary, fontWeight: FontWeight.w500),
      )),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? c.card : c.surface,
        selectedColor: primary.withValues(alpha: isDark ? 0.25 : 0.12),
        labelStyle: TextStyle(color: c.textSecondary),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary
              : isDark ? c.textMuted : c.border,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.35)
              : c.border,
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.surface,
      ),
    );
  }
}
