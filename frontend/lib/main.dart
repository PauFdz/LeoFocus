import 'package:flutter/material.dart';
import 'home_screen.dart'; // Importiamo la pagina che creiamo sotto

void main() {
  runApp(const LeoApp());
}

class LeoApp extends StatelessWidget {
  const LeoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leo Study Monitor',
      theme: ThemeData(
        primaryColor: const Color(0xFF102C53),  //Polimi Blue
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF102C53),
          primary: const Color(0xFF102C53),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}