import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1A73E8);
  static const Color secondaryColor = Color(0xFF59ADFB);
  static const Color tertiaryColor = Color(0xFF34A853);

  static const Color darkPrimaryColor = Color(0xFF4C9AFF);
  static const Color darkSecondaryColor = Color(0xFF79E2F2);
  static const Color darkTertiaryColor = Color(0xFF57CB91);

  static const Color darkBackgroundColor = Color(0xFF0D1117);
  static const Color darkSurfaceColor = Color(0xFF161B22);
  static const Color darkCardColor = Color(0xFF21262D);
  static const Color darkDividerColor = Color(0xFF30363D);

  static const Color darkTextPrimaryColor = Color(0xFFF0F6FC);
  static const Color darkTextSecondaryColor = Color(0xFFC9D1D9);
  static const Color darkTextTertiaryColor = Color(0xFF8B949E);

  static const Color lightBackgroundColor = Color(0xFFF8FAFD);
  static const Color cardColor = Colors.white;
  static const Color lightSurfaceColor = Color(0xFFF1F5F9);

  static const Color successColor = Color(0xFF34A853);
  static const Color warningColor = Color(0xFFFBBC05);
  static const Color errorColor = Color(0xFFEA4335);
  static const Color infoColor = Color(0xFF4285F4);

  static const Color darkTextColor = Color(0xFF202124);
  static const Color secondaryTextColor = Color(0xFF5F6368);
  static const Color tertiaryTextColor = Color(0xFF9AA0A6);

  static double get borderRadiusSmall => 8.0;
  static double get borderRadiusMedium => 12.0;
  static double get borderRadiusLarge => 16.0;
  static double get borderRadiusXLarge => 24.0;

  static double get spacingXSmall => 4.0;
  static double get spacingSmall => 8.0;
  static double get spacingMedium => 16.0;
  static double get spacingLarge => 24.0;
  static double get spacingXLarge => 32.0;
  static double get spacingXXLarge => 48.0;

  static const double iconSize = 24.0;
  static const double cardElevation = 2.0;
  static const EdgeInsets listTilePadding = EdgeInsets.symmetric(
    vertical: 12.0,
    horizontal: 16.0,
  );
  static const EdgeInsets cardMargin = EdgeInsets.only(top: 8, bottom: 16);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: tertiaryColor,
      error: errorColor,
      surface: lightSurfaceColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkTextColor,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: lightBackgroundColor,
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: lightBackgroundColor,
      foregroundColor: darkTextColor,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: darkTextColor,
      ),
      iconTheme: const IconThemeData(color: primaryColor),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
      ),
      margin: EdgeInsets.all(spacingSmall),
      clipBehavior: Clip.antiAlias,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimaryColor,
      secondary: darkSecondaryColor,
      tertiary: darkTertiaryColor,
      error: errorColor,
      surface: darkSurfaceColor,
      onPrimary: darkTextPrimaryColor,
      onSecondary: darkBackgroundColor,
      onSurface: darkTextPrimaryColor,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: darkBackgroundColor,
    cardColor: darkCardColor,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackgroundColor,
      foregroundColor: darkTextPrimaryColor,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: darkTextPrimaryColor,
      ),
      iconTheme: const IconThemeData(color: darkPrimaryColor),
    ),
  );
}
