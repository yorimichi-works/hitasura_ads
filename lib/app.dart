import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/first_launch_screen.dart';
import 'state/app_controller.dart';

class HitasuraAdsApp extends StatelessWidget {
  const HitasuraAdsApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ひたすら広告',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3D00),
          primary: const Color(0xFFE52A00),
          secondary: const Color(0xFFFFC400),
          surface: const Color(0xFFFFF7E8),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF7E8),
        fontFamily: 'KosugiMaru',
        fontFamilyFallback: const ['Noto Sans JP', 'Yu Gothic', 'Meiryo'],
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
          headlineMedium: TextStyle(fontWeight: FontWeight.w900),
          titleLarge: TextStyle(fontWeight: FontWeight.w900),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => controller.isRegistered
            ? AppShell(controller: controller)
            : FirstLaunchScreen(controller: controller),
      ),
    );
  }
}
