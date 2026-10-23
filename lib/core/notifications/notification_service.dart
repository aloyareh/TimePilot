import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'alarm_sound.dart';

import '../time/time_service.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// Alarm/pengingat terjadwal (PBI-13). API ditulis untuk
/// flutter_local_notifications 22.x (parameter bernama).
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  void Function(String? payload)? _onSelect;

  // Pengaturan channel dikunci Android saat channel pertama dibuat.
  // Jika kamu mengubah importance/suara, ganti channelId (atau hapus app) agar berlaku.
  static const channelId = 'task_alarm_v1';
  static const channelName = 'Alarm tugas';

  AlarmSound? _sound;
 
  /// Suara alarm pilihan pengguna (null = default). Diatur dari init() dan
  /// dari AlarmSoundNotifier.
  AlarmSound? get sound => _sound;
  void setSound(AlarmSound? sound) => _sound = sound;
 
  // Android mengunci suara per channel, jadi tiap suara memakai channel sendiri.
  String get _channelId =>
      _sound == null ? channelId : '${channelId}_${_sound!.channelSuffix}';
 
  /// Alarm baru mati setelah tantangan selesai (US-2): notifikasi tidak bisa
  /// digeser (ongoing) dan tidak hilang saat diketuk (autoCancel false).
  /// timeoutAfter = pengaman agar tidak berbunyi selamanya jika tantangan macet.
  NotificationDetails get _details => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      channelName,
      channelDescription: 'Pengingat meeting dan deadline',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      playSound: true,
      sound: _sound == null ? null : UriAndroidNotificationSound(_sound!.uri),
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
      timeoutAfter: 10 * 60 * 1000,
      // FLAG_INSISTENT (0x4): suara berulang sampai notifikasi dibatalkan.
      additionalFlags: Int32List.fromList(<int>[4]),
    ),
  );
  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Aman dipanggil berulang. [onSelect] hanya dipakai dari pemanggilan pertama.
  /// Panggilan pertama dilakukan di MainApp dengan handler yang membuka halaman tugas.
  Future<void> init({void Function(String? payload)? onSelect}) async {
    if (onSelect != null) _onSelect = onSelect;
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
      onDidReceiveNotificationResponse: (r) => _onSelect?.call(r.payload),
    );
    _sound = await const AlarmSoundStore().read();
    _ready = true;
  }

  /// Payload notifikasi yang meluncurkan app dari kondisi mati (null jika bukan).
  Future<String?> launchPayload() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d == null || !d.didNotificationLaunchApp) return null;
    return d.notificationResponse?.payload;
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

  /// Jadwalkan alarm pada instan [whenUtc]. Mengembalikan false jika sudah lewat.
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
      // alarmClock: setAlarmClock, tidak ditunda Doze; butuh izin alarm tepat.
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