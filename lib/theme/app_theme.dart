import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Color palette — mapped from CSS design tokens
//
//  Primary scale  (a0 → a50: dark → light blue-violet)
//    a0  #333aff   a10 #3f57ff   a20 #506fff
//    a30 #6284ff   a40 #7797ff   a50 #8ca9ff
//
//  Surface scale  (a0 → a50: near-black → mid-gray)
//    a0  #121212   a10 #252525   a20 #393939
//    a30 #4f4f4f   a40 #666666   a50 #7d7d7d
//
//  Tonal surface  (a0 → a50: dark blue-black → mid blue-gray)
//    a0  #141926   a10 #272c39   a20 #3b404c
//    a30 #515560   a40 #676b75   a50 #7f828b
//
//  Semantic a0 = darkest  |  a10 = mid  |  a20 = lightest
//    success   #22946e / #5ba989 / #86bfa6
//    warning   #a87a2a / #ba945a / #cbae84
//    danger    #9c2121 / #b4544c / #ca7f77
//    info      #21498a / #4b6ca2 / #7590ba
// ═══════════════════════════════════════════════════════════════════════════════

// ── Semantic colors — immutable, same values in both themes ───────────────────
class AppColors {
  AppColors._();

  // Default primary scale — kept as compile-time constants so they can be used
  // in const widget constructors.  Dynamic callers should prefer
  // context.colors.primary / primaryLight / accent instead.
  static const Color primary      = Color(0xFF333AFF);
  static const Color primaryLight = Color(0xFF7797FF);
  static const Color accent       = Color(0xFF8CA9FF);

  // Success (a10 for text/icons, a0 for solid backgrounds)
  static const Color success      = Color(0xFF5BA989);
  static const Color successDark  = Color(0xFF22946E);

  // Warning
  static const Color warning      = Color(0xFFBA945A);
  static const Color warningDark  = Color(0xFFA87A2A);

  // Danger
  static const Color danger       = Color(0xFFB4544C);
  static const Color dangerDark   = Color(0xFF9C2121);

  // Info
  static const Color info         = Color(0xFF4B6CA2);
  static const Color infoDark     = Color(0xFF21498A);

  // ── Predefined primary colour swatches (OEM whitelabel) ───────────────────
  static const List<({String label, Color color})> primarySwatches = [
    (label: 'Blue',    color: Color(0xFF333AFF)),
    (label: 'Indigo',  color: Color(0xFF4338CA)),
    (label: 'Violet',  color: Color(0xFF7C3AED)),
    (label: 'Rose',    color: Color(0xFFE11D48)),
    (label: 'Red',     color: Color(0xFFDC2626)),
    (label: 'Orange',  color: Color(0xFFEA580C)),
    (label: 'Teal',    color: Color(0xFF0F766E)),
    (label: 'Green',   color: Color(0xFF16A34A)),
  ];
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
    surface:       Color(0xFF141926),
    card:          Color(0xFF272C39),
    border:        Color(0xFF3B404C),
    textPrimary:   Color(0xFFE4E6F0),
    textSecondary: Color(0xFF7F828B),
    textMuted:     Color(0xFF676B75),
  );

  // ── Light palette ─────────────────────────────────────────────────────────
  static const light = AppColorScheme(
    background:    Color(0xFFEEF0F7),
    surface:       Color(0xFFFFFFFF),
    card:          Color(0xFFFFFFFF),
    border:        Color(0xFFD8DBE8),
    textPrimary:   Color(0xFF141926),
    textSecondary: Color(0xFF515560),
    textMuted:     Color(0xFF676B75),
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
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
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
