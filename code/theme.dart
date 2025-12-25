import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/app_colors.dart';

// --- VISUAL CONSTANTS (Legacy for backwards compatibility) ---
const Color kPrimary = AppColors.primaryBrand;
const Color kPrimaryDark = AppColors.primaryBrandDark;
const Color kBackground = AppColors.backgroundMain;
const Color kSurface = AppColors.surface;
const Color kTextTitle = AppColors.textPrimary;
const Color kTextBody = AppColors.textPrimary;
const Color kTextMeta = AppColors.textSecondary;
const Color kBorder = AppColors.disabled;
const Color kBorderDark = AppColors.disabledDark;

class MyCatholicTheme {
  
  // LIGHT THEME
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundMain, // #FFFFFF
      primaryColor: AppColors.primaryBrand, // #0088CC
      
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primaryBrand,
        onPrimary: Colors.white,
        secondary: AppColors.primaryBrand,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.surface, // #F5F5F5
        onSurface: AppColors.textPrimary, // #000000
      ),

      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryBrand, // Blue
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface, // #F5F5F5
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      
      dividerTheme: const DividerThemeData(color: AppColors.disabled),
    );
  }

  // DARK THEME
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundMainDark, // #121212
      primaryColor: AppColors.primaryBrandDark, // #4DA3D9
      
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primaryBrandDark,
        onPrimary: Colors.black,
        secondary: AppColors.primaryBrandDark,
        onSecondary: Colors.black,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.surfaceDark, // #1C1C1C
        onSurface: AppColors.textPrimaryDark, // #FFFFFF
      ),

      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark, // #1C1C1C
        foregroundColor: AppColors.textPrimaryDark, // White
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.textPrimaryDark, fontSize: 20, fontWeight: FontWeight.bold
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceDark, // #1C1C1C
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      
      dividerTheme: const DividerThemeData(color: AppColors.disabledDark),
    );
  }
}

