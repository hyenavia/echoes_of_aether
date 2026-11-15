import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../application/services/notification_scheduler.dart';
import '../../domain/services/notification_planner.dart';

/// Implementasi platform [NotificationScheduler] menggunakan
/// `flutter_local_notifications` + `timezone` dengan mode inexact (tanpa izin
/// alarm tepat waktu). Mengetuk notifikasi hanya membuka aplikasi.
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _initialized = true;
      return;
    }
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  @override
  Future<void> replaceAll(List<PlannedNotification> planned) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    await _ensureInitialized();
    await _plugin.cancelAll();

    for (final item in planned) {
      final scheduledDate = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC,
        item.fireAtMs,
      );
      final channelName = switch (item.channel) {
        NotificationPlanner.channelOffline => 'Offline Progression',
        NotificationPlanner.channelEventShop => 'Event Shop',
        _ => 'Boss Events',
      };
      final androidDetails = AndroidNotificationDetails(
        item.channel,
        channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      await _plugin.zonedSchedule(
        id: item.id,
        title: item.title,
        body: item.body,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    await _ensureInitialized();
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await androidImpl?.requestNotificationsPermission();
    return granted ?? true;
  }
}
