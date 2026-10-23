import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/alarm_sound.dart';
import '../../core/notifications/notification_service.dart';
import '../tasks/task_providers.dart';

/// Suara alarm yang dipilih (null = suara default aplikasi).
class AlarmSoundNotifier extends AsyncNotifier<AlarmSound?> {
  @override
  Future<AlarmSound?> build() => ref.read(alarmSoundStoreProvider).read();

  /// Mengembalikan pesan error, atau null bila berhasil/dibatalkan.
  Future<String?> importSound() async {
    try {
      final picked = await AlarmSoundChannel.pickAndImport();
      if (picked == null) return null;
      final old = state.value;
      await _apply(picked);
      if (old != null) await AlarmSoundChannel.remove(old.uri);
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Gagal mengimpor suara.';
    } catch (_) {
      return 'Gagal mengimpor suara.';
    }
  }

  Future<void> reset() async {
    final old = state.value;
    await _apply(null);
    if (old != null) await AlarmSoundChannel.remove(old.uri);
  }

  /// Channel notifikasi dikunci Android per suara, jadi alarm yang sudah
  /// terjadwal dijadwalkan ulang agar memakai channel/suara yang baru.
  Future<void> _apply(AlarmSound? sound) async {
    await ref.read(alarmSoundStoreProvider).write(sound);
    final svc = ref.read(notificationServiceProvider);
    await svc.init();
    svc.setSound(sound);
    state = AsyncData(sound);
    await ref
        .read(tasksProvider.notifier)
        .resyncAlarms(ref.read(tasksProvider));
  }
}

final alarmSoundProvider =
    AsyncNotifierProvider<AlarmSoundNotifier, AlarmSound?>(
      AlarmSoundNotifier.new,
    );