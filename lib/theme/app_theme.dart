import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// SmartRoute design system — extracted from the website (source of truth).
///
/// References (do not invent new values):
///   frontend/src/index.css      — tokens, typography scale, component recipes
///   frontend/tailwind.config.js — "Strict Uber-inspired neutrals", radii,
///                                 shadows, Inter font stack
///   frontend/src/components/dashboard-shared.jsx — status/badge/empty states
///
/// The website's language: pure black canvas, hairline #333 borders, #1F1F1F
/// surfaces, white primary actions with black text, tight negative tracking,
/// 6/8/12/16 radii, shadows only for floating surfaces. No gradients, no
/// purple, no glassmorphism.
/// ════════════════════════════════════════════════════════════════════════════

/// Raw palette (`--color-*` in index.css).
class AppColors {
  AppColors._();

  // Ink / paper
  static const Color ink = Color(0xFF000000);
  static const Color inkSoft = Color(0xFF111111);
  static const Color inkSurface = Color(0xFF1F1F1F);
  static const Color paper = Color(0xFFFFFFFF);

  // Neutral scale
  static const Color gray50 = Color(0xFFF6F6F6);
  static const Color gray100 = Color(0xFFEEEEEE);
  static const Color gray200 = Color(0xFFE2E2E2);
  static const Color gray300 = Color(0xFFD6D6D6);
  static const Color gray400 = Color(0xFFAFAFAF);
  static const Color gray500 = Color(0xFF8A8A8A);
  static const Color gray600 = Color(0xFF6B6B6B);
  static const Color gray700 = Color(0xFF545454);
  static const Color gray800 = Color(0xFF333333);
  static const Color gray900 = Color(0xFF1F1F1F);

  // Semantic accents
  static const Color accent = Color(0xFF276EF1);
  static const Color accentStrong = Color(0xFF1A5AD7);
  static const Color error = Color(0xFFD93025);
  static const Color warning = Color(0xFFF5A623);

  // ── Dark theme semantics (site `.dark`) — the app's mode ──
  static const Color bg = ink; // #000 canvas
  static const Color surface = inkSurface; // #1F1F1F cards / fields
  static const Color surfaceAlt = Color(0xFF2A2A2A); // nested rows, skeletons
  static const Color border = gray800; // #333 hairline
  static const Color borderStrong = gray700; // #545454
  static const Color textPrimary = paper;
  static const Color textSecondary = gray400; // #AFAFAF muted
  static const Color textSubtle = gray500; // #8A8A8A eyebrows / status
  static const Color textDisabled = gray700; // #545454
  static const Color readSurface = Color(0xFF161616); // read notifications
  static const Color overlay = Color(0x99000000);

  /// Translucent status tints (site: `border-[#276EF1]/25 bg-[#276EF1]/10`).
  static Color tint(Color c, double alpha) => c.withValues(alpha: alpha);
}

/// Radii (`--radius-*`): 6 / 8 / 12 / 16 only.
class AppRadius {
  AppRadius._();
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double pill = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Spacing scale — 4-based, matching the website's rhythm.
class AppSpacing {
  AppSpacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// Screen gutters (site: `uber-container` 16 → 32 → 48).
  static const double gutter = 20;
}

/// Shadows (`--shadow-*`) — floating surfaces only.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Bottom-sheet lift used by the website's booking panel on mobile.
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 30, offset: Offset(0, -8)),
  ];
  static const List<BoxShadow> none = [];
}

/// Motion — short, purposeful durations. Premium mobile UIs move fast: the
/// site's transitions are 150–250ms with ease-out, never bouncy.
class AppMotion {
  AppMotion._();

  /// Press / hover feedback, chips, icon buttons.
  static const Duration fast = Duration(milliseconds: 120);

  /// State swaps, sheet content changes, expanding rows.
  static const Duration base = Duration(milliseconds: 180);

  /// Page transitions and bottom-sheet presentation.
  static const Duration slow = Duration(milliseconds: 260);

  /// Map camera moves (slightly slower — the map has visual mass).
  static const Duration map = Duration(milliseconds: 420);

  /// Enter: decelerate. Exit: accelerate. Both ease-out-ish, no overshoot.
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve move = Curves.easeInOutCubic;

  /// Snap sizes for the map-first bottom sheet (collapsed / expanded).
  static const double sheetMin = 0.42;
  static const double sheetMid = 0.62;
  static const double sheetMax = 0.94;
}

/// Typography — Inter metrics (sizes / weights / tracking / line height).
class AppType {
  AppType._();

  /// `font-variant-numeric: tabular-nums` for prices, times, plates.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// `.uber-hero`
  static const TextStyle hero = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -1.26, // -0.03em
  );

  /// `.uber-page-title`
  static const TextStyle pageTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.75, // -0.025em
  );

  /// `.uber-section-title`
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.48, // -0.02em
  );

  /// `text-[28px] font-bold tracking-[-0.02em]` (booking panel headline)
  static const TextStyle panelTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.56,
  );

  /// `.uber-card-title`
  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.18, // -0.01em
  );

  /// `text-[15px] font-semibold tracking-[-0.01em]`
  static const TextStyle title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.15,
  );

  /// `.uber-body` / body copy (site `font-size: 15px`)
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  /// `.uber-small`
  static const TextStyle small = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle smallStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  /// `.uber-caption`
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Form labels (`text-[13px] font-semibold`)
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// `.uber-eyebrow` / `.mob-section-label`
  static const TextStyle eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.88, // 0.08em
  );

  /// Status badge text (site: 10px / 600 / uppercase / 0.06em)
  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.6,
  );

  /// Numeric data (prices, distance, plates).
  static const TextStyle data = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.15,
    fontFeatures: tabular,
  );
}

/// Component recipes (`.uber-btn-*`, `.uber-field`, `.uber-card`).
class AppDecor {
  AppDecor._();

  /// `.uber-card` — #1F1F1F, 1px #333, 12px, 20/24 padding.
  static BoxDecoration card({bool elevated = false}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: elevated ? AppShadows.sm : null,
      );

  /// Emphasised card (site: `border-black dark:border-white` — active booking).
  static BoxDecoration cardEmphasis() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.paper, width: 1.25),
      );

  /// `.uber-float` — floating panel: 16px, md shadow.
  static BoxDecoration floating({bool topOnly = false}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: topOnly ? AppRadius.sheet : AppRadius.all(AppRadius.xl),
        border: topOnly
            ? const Border(top: BorderSide(color: AppColors.border))
            : Border.all(color: AppColors.border),
        boxShadow: topOnly ? AppShadows.sheet : AppShadows.md,
      );

  /// `.uber-field` — 52px, #1F1F1F, 1px #333, radius 8.
  static BoxDecoration field({bool focused = false}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.field,
        border: Border.all(
          color: focused ? AppColors.paper : AppColors.border,
        ),
      );

  /// Outlined row with no fill (site: `rounded-xl border px-4 py-3`) — used for
  /// toggles and lightweight option rows so they don't compete with cards.
  static BoxDecoration flatRow() => BoxDecoration(
        borderRadius: AppRadius.all(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      );

  /// Nested info row (site: rounded-xl + border + #2A2A2A).
  static BoxDecoration infoRow() => BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.all(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      );
}

/// ThemeData wiring so Material widgets inherit the website's language.
class AppTheme {
  AppTheme._();

  /// ── Backward-compatible aliases (existing screens keep compiling while
  ///    inheriting the corrected, website-faithful values) ──
  static const Color scaffoldBg = AppColors.bg;
  static const Color surfaceColor = AppColors.surface;
  static const Color accentBlue = AppColors.accent;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textTertiary = AppColors.textSubtle;
  static const Color textDisabled = AppColors.textDisabled;
  static const Color readNotifBg = AppColors.readSurface;
  static const Color borderColor = AppColors.border;
  static const Color borderDark = AppColors.gray900;

  static const double radiusSm = AppRadius.md; // 8  (was 12)
  static const double radiusMd = AppRadius.lg; // 12 (was 16)
  static const double radiusLg = AppRadius.xl; // 16 (was 20)
  static const double radiusXl = AppRadius.xl; // 16 (was 24)

  static const TextStyle headingLarge = AppType.pageTitle;
  static const TextStyle headingMedium = AppType.sectionTitle;
  static const TextStyle headingSmall = AppType.cardTitle;
  static const TextStyle bodyRegular = AppType.body;
  static const TextStyle bodySmall = AppType.caption;
  static const TextStyle labelUppercase = AppType.eyebrow;

  static TextTheme get textTheme => const TextTheme(
        displayLarge: AppType.hero,
        displayMedium: AppType.pageTitle,
        displaySmall: AppType.panelTitle,
        headlineLarge: AppType.pageTitle,
        headlineMedium: AppType.sectionTitle,
        headlineSmall: AppType.cardTitle,
        titleLarge: AppType.cardTitle,
        titleMedium: AppType.title,
        titleSmall: AppType.smallStrong,
        bodyLarge: AppType.body,
        bodyMedium: AppType.small,
        bodySmall: AppType.caption,
        labelLarge: AppType.bodyStrong,
        labelMedium: AppType.label,
        labelSmall: AppType.eyebrow,
      ).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      );

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.paper, // site dark primary = white
      onPrimary: AppColors.inkSoft,
      secondary: AppColors.surfaceAlt,
      onSecondary: AppColors.paper,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.paper,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamilyFallback: const ['Roboto', 'Arial', 'Helvetica', 'sans-serif'],
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: const TextStyle(
          color: AppColors.textDisabled,
          fontSize: 15,
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(color: AppColors.paper, width: 1.25),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: const BorderSide(color: AppColors.error, width: 1.25),
        ),
      ),
      // Primary action: white on black text (site `.dark .uber-btn-primary`),
      // 48–52px tall, radius 8, 15–16px semibold.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.paper,
          foregroundColor: AppColors.inkSoft,
          disabledBackgroundColor: AppColors.surfaceAlt,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
          ),
        ),
      ),
      // Secondary: transparent, 1px #333, white text.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.paper,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          side: const BorderSide(color: AppColors.border),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.paper,
          disabledForegroundColor: AppColors.textDisabled,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          minimumSize: const Size(0, 40),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.cardTitle,
        iconTheme: IconThemeData(color: AppColors.paper, size: 20),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: AppType.small.copyWith(color: AppColors.paper),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.all(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        dragHandleColor: AppColors.gray300,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.all(AppRadius.xl),
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: AppType.cardTitle,
        contentTextStyle: AppType.body.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.paper,
        linearTrackColor: AppColors.surfaceAlt,
        circularTrackColor: AppColors.surfaceAlt,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.gray400,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.paper
              : AppColors.surfaceAlt,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.paper
              : AppColors.border,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 20),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
