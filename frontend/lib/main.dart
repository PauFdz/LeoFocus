import 'home_page_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'process_service.dart';
import 'theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LeonardoService()),
      ],
      child: const LeonardoApp(),
    ),
  );
}

class LeonardoApp extends StatelessWidget {
  const LeonardoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leonardo',
      theme: LeonardoTheme.themeData,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
