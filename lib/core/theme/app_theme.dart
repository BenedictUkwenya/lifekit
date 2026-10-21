import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// App-wide theme. Screens that style widgets explicitly keep their look;
/// everything left to defaults (buttons, dialogs, sheets, snackbars, page
/// transitions, text) inherits a consistent, modern LifeKit style.
///
/// Intentionally no global InputDecorationTheme: many screens draw custom
/// fields inside their own containers and a global fill/border would clash.
class AppTheme {
  static const _radius = 16.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: Colors.white,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
    );
    final buttonText = GoogleFonts.poppins(
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      splashFactory: InkSparkle.splashFactory,
      // Motion: modern forward-fade on Android, native slide on iOS.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: shape,
          textStyle: buttonText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: shape,
          textStyle: buttonText,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F2937),
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.2),
        selectionHandleColor: AppColors.primary,
      ),
    );
  }
}
