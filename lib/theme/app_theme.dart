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

// ── Semantic colors — same values in both themes ──────────────────────────────
class AppColors {
  AppColors._();

  // Primary
  static const Color primary      = Color(0xFF333AFF); // a0 — buttons, active borders
  static const Color primaryLight = Color(0xFF7797FF); // a40 — nav selected, text links
  static const Color accent       = Color(0xFF8CA9FF); // a50 — softest tint / secondary

  // Success (a10 for text/icons, a0 for solid backgrounds)
  static const Color success      = Color(0xFF5BA989); // --clr-success-a10
  static const Color successDark  = Color(0xFF22946E); // --clr-success-a0

  // Warning
  static const Color warning      = Color(0xFFBA945A); // --clr-warning-a10
  static const Color warningDark  = Color(0xFFA87A2A); // --clr-warning-a0

  // Danger
  static const Color danger       = Color(0xFFB4544C); // --clr-danger-a10
  static const Color dangerDark   = Color(0xFF9C2121); // --clr-danger-a0

  // Info
  static const Color info         = Color(0xFF4B6CA2); // --clr-info-a10
  static const Color infoDark     = Color(0xFF21498A); // --clr-info-a0
}

// ── Structural colors — differ between light and dark ─────────────────────────
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // ── Dark palette — CSS surface + tonal surface tokens ─────────────────────
  //   background  →  --clr-surface-a0        #121212
  //   surface     →  --clr-surface-tonal-a0  #141926
  //   card        →  --clr-surface-tonal-a10 #272c39
  //   border      →  --clr-surface-tonal-a20 #3b404c
  //   textPrimary → near-white with subtle tonal tint
  //   textSecondary → --clr-surface-tonal-a50 #7f828b
  //   textMuted     → --clr-surface-tonal-a40 #676b75
  static const dark = AppColorScheme(
    background:    Color(0xFF121212),
    surface:       Color(0xFF141926),
    card:          Color(0xFF272C39),
    border:        Color(0xFF3B404C),
    textPrimary:   Color(0xFFE4E6F0),
    textSecondary: Color(0xFF7F828B),
    textMuted:     Color(0xFF676B75),
  );

  // ── Light palette — inverted tonal surface tokens ─────────────────────────
  //   background  → very light tonal  (near-white with blue tint)
  //   surface     → pure white
  //   card        → pure white
  //   border      → light tonal border
  //   textPrimary → --clr-surface-tonal-a0  #141926 (dark ink on light)
  //   textSecondary → --clr-surface-tonal-a30 #515560
  //   textMuted     → --clr-surface-tonal-a40 #676b75
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
  }) =>
      AppColorScheme(
        background:    background    ?? this.background,
        surface:       surface       ?? this.surface,
        card:          card          ?? this.card,
        border:        border        ?? this.border,
        textPrimary:   textPrimary   ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted:     textMuted     ?? this.textMuted,
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

  static ThemeData get darkTheme  => _build(AppColorScheme.dark,  Brightness.dark);
  static ThemeData get lightTheme => _build(AppColorScheme.light, Brightness.light);

  static ThemeData _build(AppColorScheme c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness:  brightness,
        primary:     AppColors.primary,
        onPrimary:   Colors.white,
        secondary:   AppColors.accent,
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primary),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: c.textSecondary),
        hintStyle: TextStyle(color: c.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dividerColor: c.border,
      dividerTheme: DividerThemeData(color: c.border),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: AppColors.primaryLight,
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
        selectedColor: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
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
              ? AppColors.primary
              : isDark ? c.textMuted : c.border,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary.withValues(alpha: 0.35)
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
