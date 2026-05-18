import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Semantic colors — identical in both light and dark mode ──────────────────
class AppColors {
  AppColors._();

  static const Color primary      = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color accent       = Color(0xFF38BDF8);
  static const Color success      = Color(0xFF22C55E);
  static const Color successDark  = Color(0xFF16A34A);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningDark  = Color(0xFFD97706);
  static const Color danger       = Color(0xFFEF4444);
  static const Color dangerDark   = Color(0xFFDC2626);
}

// ── Structural colors — differ between light and dark mode ───────────────────
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

  // ── Dark palette (original) ────────────────────────────────────────────────
  static const dark = AppColorScheme(
    background:    Color(0xFF0B0F1A),
    surface:       Color(0xFF131929),
    card:          Color(0xFF1A2236),
    border:        Color(0xFF253047),
    textPrimary:   Color(0xFFE2E8F0),
    textSecondary: Color(0xFF94A3B8),
    textMuted:     Color(0xFF475569),
  );

  // ── Light palette ──────────────────────────────────────────────────────────
  static const light = AppColorScheme(
    background:    Color(0xFFF1F5F9),
    surface:       Color(0xFFFFFFFF),
    card:          Color(0xFFFFFFFF),
    border:        Color(0xFFE2E8F0),
    textPrimary:   Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted:     Color(0xFF94A3B8),
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

// ── Convenience accessor ─────────────────────────────────────────────────────
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
        brightness:   brightness,
        primary:      AppColors.primary,
        onPrimary:    Colors.white,
        secondary:    AppColors.accent,
        onSecondary:  Colors.white,
        error:        AppColors.danger,
        onError:      Colors.white,
        surface:      c.surface,
        onSurface:    c.textPrimary,
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
        backgroundColor: c.surface,
        selectedColor: AppColors.primary,
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
              ? AppColors.primary.withValues(alpha: 0.4)
              : c.border,
        ),
      ),
    );
  }
}
