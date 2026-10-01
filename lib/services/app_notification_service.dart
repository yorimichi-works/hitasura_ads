import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';

/// Keeps the two local reminders in sync with the current device state.
class AppNotificationService {
  AppNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const energyId = 1001;
  static const inactiveId = 1002;
  static const inactiveDelay = Duration(days: 3);

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;
  Future<void> _pending = Future.value();

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  Future<void> initialize() {
    if (!_supported) return Future.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    timezone_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<void> requestPermission() async {
    if (!_supported) return;
    await initialize();
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: true);
    }
  }

  Future<void> updateEnergy({
    required bool enabled,
    required DateTime? fullAt,
  }) => _enqueue(() async {
    await initialize();
    if (!_supported) return;
    await _plugin.cancel(id: energyId);
    if (!enabled || fullAt == null || !fullAt.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: energyId,
      title: L10n.ui('stamina_full_title'),
      body: L10n.ui('stamina_full_body'),
      scheduledDate: tz.TZDateTime.from(fullAt, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  });

  Future<void> updateInactivity({
    required bool enabled,
    required bool appActive,
  }) => _enqueue(() async {
    await initialize();
    if (!_supported) return;
    await _plugin.cancel(id: inactiveId);
    if (!enabled || appActive) return;
    await _plugin.zonedSchedule(
      id: inactiveId,
      title: L10n.ui('return_reminder_title'),
      body: L10n.ui('return_reminder_body'),
      scheduledDate: tz.TZDateTime.from(
        DateTime.now().add(inactiveDelay),
        tz.UTC,
      ),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  });

  Future<void> _enqueue(Future<void> Function() action) {
    _pending = _pending.catchError((Object _) {}).then((_) => action());
    return _pending;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'game_reminders',
      'Game reminders',
      channelDescription: 'Ticket recovery and return reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );
}
