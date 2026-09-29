import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'arcade/engine/audio.dart';
import 'arcade/engine/draw.dart';
import 'arcade/engine/game_view.dart';
import 'l10n/l10n.dart';
import 'services/rewarded_ad_service.dart';
import 'state/app_controller.dart';
import 'ui/first_launch.dart';
import 'ui/home.dart';
import 'ui/kit.dart';

/// Connects the engine's text hooks to the current language.
void applyLanguage() {
  EngineText.lang = L10n.code;
  EngineText.word = L10n.word;
  EngineText.ui = L10n.ui;
  D.textDirection = L10n.direction;
}

class HitasuraAdsApp extends StatelessWidget {
  const HitasuraAdsApp({super.key, required this.controller, this.rewardedAdService});

  final AppController controller;
  final RewardedAdService? rewardedAdService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        applyLanguage();
        ArcadeAudio.instance.muted = !controller.soundEffectsEnabled;
        final lang = L10n.lang;
        return MaterialApp(
          title: L10n.ui('app_title'),
          debugShowCheckedModeBanner: false,
          locale: lang.flutterLocale,
          supportedLocales: [for (final l in languages) l.flutterLocale],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            fontFamily: K.font,
            fontFamilyFallback: D.fontFallback,
            colorScheme: ColorScheme.fromSeed(seedColor: K.pink, brightness: Brightness.dark, primary: K.pink, secondary: K.yellow),
            scaffoldBackgroundColor: K.night,
            snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFFFFFFFF),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              hintStyle: TextStyle(color: Color(0x88140E2A)),
            ),
          ),
          builder: (context, child) => Directionality(textDirection: L10n.direction, child: child!),
          home: controller.isRegistered
              ? HomeScreen(controller: controller, rewardedAdService: rewardedAdService)
              : FirstLaunchScreen(controller: controller),
        );
      },
    );
  }
}
