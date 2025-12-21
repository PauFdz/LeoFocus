import 'home_page_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Assicurati di averlo nel pubspec
import 'process_service.dart';
import 'theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LeonardoService()),
      ],
      child: const LeoFocusApp(),
    ),
  );
}

class LeoFocusApp extends StatelessWidget {
  const LeoFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeoFocus',
      theme: ThemeData(
        // CORREZIONE QUI SOTTO: italiannoTextTheme (tutto minuscolo fino a TextTheme)
        textTheme: GoogleFonts.italiannoTextTheme(
          Theme.of(context).textTheme,
        ),
      ).copyWith(
        colorScheme: LeonardoTheme.themeData.colorScheme,
        scaffoldBackgroundColor: LeonardoTheme.themeData.scaffoldBackgroundColor,
        elevatedButtonTheme: LeonardoTheme.themeData.elevatedButtonTheme,
        inputDecorationTheme: LeonardoTheme.themeData.inputDecorationTheme,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}