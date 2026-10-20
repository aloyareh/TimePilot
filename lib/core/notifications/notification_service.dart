import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import '../time/time_service.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const channelId = 'task_alarm_v1';
  static const channelName = 'Alarm tugas';

  static final _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Pengingat meeting dan deadline',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      autoCancel: true,
      // FLAG_INSISTENT (0x4): suara berulang sampai notifikasi dibuka/dihapus.
      additionalFlags: Int32List.fromList(<int>[4]),
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> init({void Function(String? payload)? onSelect}) async {
    if (_ready) return;
    TimeService.init(); // memuat database zona waktu
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation(AppZones.wib)); // cadangan
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) => onSelect?.call(r.payload),
    );
    _ready = true;
  }

  Future<({bool notifications, bool exactAlarm})> requestPermissions() async {
    final android = _android;
    if (android == null) return (notifications: false, exactAlarm: false);
    final notif = await android.requestNotificationsPermission() ?? false;
    var exact = await android.canScheduleExactNotifications() ?? false;
    if (!exact) {
      exact = await android.requestExactAlarmsPermission() ?? false;
    }
    return (notifications: notif, exactAlarm: exact);
  }

  Future<bool> scheduleAt({
    required int id,
    required DateTime whenUtc,
    required String title,
    String? body,
    String? payload,
  }) async {
    final when = tz.TZDateTime.from(whenUtc, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return false;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      title: title,
      body: body,
      payload: payload,
    );
    return true;
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;
}