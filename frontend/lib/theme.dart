import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeonardoTheme {
  // Elegant Renaissance-inspired palette
  static const Color background = Color(0xFFFAF8F5); // Warm off-white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1A1614); // Deep warm black
  static const Color inkLight = Color(0xFF6B675E); // Muted warm grey
  //static const Color accent = Color(0xFFB8442C); // Terracotta red
  static const Color accent = Color(0xFF102C53); // Polimi blue
  static const Color gold = Color(0xFFD4A574); // Renaissance gold
  static const Color success = Color(0xFF2D7A4F); // Elegant green

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.cinzel(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.cinzel(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 18,
          color: ink,
          height: 1.6,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          color: inkLight,
          height: 1.5,
        ),
        displayLarge: GoogleFonts.chivoMono(
          fontSize: 72,
          fontWeight: FontWeight.w300,
          color: ink,
          letterSpacing: -2.0,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: inkLight.withOpacity(0.1), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        hintStyle: GoogleFonts.inter(
          color: inkLight.withOpacity(0.5),
          fontSize: 14,
        ),
        prefixIconColor: inkLight,
        suffixIconColor: inkLight,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.white.withOpacity(0.2);
              }
              if (states.contains(WidgetState.hovered)) {
                return Colors.white.withOpacity(0.1);
              }
              return null;
            },
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: inkLight.withOpacity(0.1),
        thickness: 1,
      ),

      iconTheme: IconThemeData(
        color: inkLight,
        size: 24,
      ),
    );
  }
}