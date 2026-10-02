import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'arcade/engine/audio.dart';
import 'arcade/engine/draw.dart';
import 'arcade/engine/game_view.dart';
import 'l10n/l10n.dart';
import 'services/rewarded_ad_service.dart';
import 'services/app_notification_service.dart';
import 'services/app_licenses.dart';
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

class HitasuraAdsApp extends StatefulWidget {
  const HitasuraAdsApp({
    super.key,
    required this.controller,
    this.rewardedAdService,
  });

  final AppController controller;
  final RewardedAdService? rewardedAdService;

  @override
  State<HitasuraAdsApp> createState() => _HitasuraAdsAppState();
}

class _HitasuraAdsAppState extends State<HitasuraAdsApp>
    with WidgetsBindingObserver {
  final AppNotificationService _notifications = AppNotificationService();
  DateTime? _lastFullAt;
  bool? _lastEnabled;
  String? _lastLanguage;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    registerAppLicenses();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncNotifications);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncNotifications();
    });
  }

  void _syncNotifications() {
    final controller = widget.controller;
    if (!controller.isRegistered) return;
    final enabled = controller.notificationsEnabled;
    final fullAt = controller.searchEnergyFullAt;
    if (_lastEnabled == enabled &&
        _lastFullAt == fullAt &&
        _lastLanguage == L10n.code) {
      return;
    }
    _lastEnabled = enabled;
    _lastFullAt = fullAt;
    _lastLanguage = L10n.code;
    unawaited(_notifications.updateEnergy(enabled: enabled, fullAt: fullAt));
    if (enabled) unawaited(_notifications.requestPermission());
    if (!enabled) {
      unawaited(
        _notifications.updateInactivity(enabled: false, appActive: _appActive),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    if (!widget.controller.isRegistered) return;
    unawaited(
      _notifications.updateInactivity(
        enabled: widget.controller.notificationsEnabled,
        appActive: active,
      ),
    );
    if (active) _syncNotifications();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncNotifications);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        applyLanguage();
        ArcadeAudio.instance.muted = !widget.controller.soundEffectsEnabled;
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
            colorScheme: ColorScheme.fromSeed(
              seedColor: K.pink,
              brightness: Brightness.dark,
              primary: K.pink,
              secondary: K.yellow,
            ),
            scaffoldBackgroundColor: K.night,
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Color(0xFFFFFFFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              hintStyle: TextStyle(color: Color(0x88140E2A)),
            ),
          ),
          builder: (context, child) =>
              Directionality(textDirection: L10n.direction, child: child!),
          home: widget.controller.isRegistered
              ? HomeScreen(
                  controller: widget.controller,
                  rewardedAdService: widget.rewardedAdService,
                )
              : FirstLaunchScreen(controller: widget.controller),
        );
      },
    );
  }
}
