import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

/// پالت رنگی تیره‌ی اپ (هماهنگ با طرح پیشنهادی).
class AppColors {
  static const background = Color(0xFF0B1220);
  static const surface = Color(0xFF141C2E);
  static const surfaceVariant = Color(0xFF1B2540);
  static const border = Color(0xFF243050);
  static const accent = Color(0xFF22D3EE);
  static const accentBlue = Color(0xFF3B82F6);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
}

void main() {
  runApp(const V2raySmartApp());
}

class V2raySmartApp extends StatelessWidget {
  const V2raySmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.vazirmatnTextTheme(ThemeData.dark().textTheme);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accentBlue,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    );

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: baseTextTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: GoogleFonts.vazirmatn(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: AppColors.accentBlue,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.vazirmatn(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          textStyle: GoogleFonts.vazirmatn(fontSize: 15, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accentBlue,
        thumbColor: AppColors.accentBlue,
        inactiveTrackColor: AppColors.border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceVariant,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return MaterialApp(
      title: 'سینره وی‌پی‌ان',
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: const Locale('fa'),
      // چون بسته‌های لوکالایزیشن رسمی فارسی نصب نشده‌اند، جهت راست‌به‌چپ
      // را مستقیماً روی کل درخت ویجت اعمال می‌کنیم تا چیدمان درست باشد.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}
