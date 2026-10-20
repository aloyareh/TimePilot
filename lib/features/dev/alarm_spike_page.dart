import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';

/// SEMENTARA: halaman uji alarm (spike PBI-13). Hapus setelah alarm tersambung ke tugas.
class AlarmSpikePage extends ConsumerStatefulWidget {
  const AlarmSpikePage({super.key});

  @override
  ConsumerState<AlarmSpikePage> createState() => _AlarmSpikePageState();
}

class _AlarmSpikePageState extends ConsumerState<AlarmSpikePage> {
  final _log = <String>[];

  NotificationService get _svc => ref.read(notificationServiceProvider);

  void _add(String s) {
    final t = TimeOfDay.now();
    setState(() => _log.insert(0, '${t.format(context)}  $s'));
  }

  Future<void> _guard(String label, Future<String> Function() fn) async {
    try {
      _add('$label: ${await fn()}');
    } catch (e) {
      _add('$label ERROR: $e');
    }
  }

  Future<String> _schedule(int id, Duration after) async {
    await _svc.init(onSelect: (p) => _add('diketuk, payload=$p'));
    final when = DateTime.now().toUtc().add(after);
    final ok = await _svc.scheduleAt(
      id: id,
      whenUtc: when,
      title: 'Tes alarm Time Pilot',
      body: 'Dijadwalkan ${after.inSeconds} detik lalu',
      payload: 'spike-$id',
    );
    return ok ? 'terjadwal (${await _svc.pendingCount()} tertunda)' : 'sudah lewat';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spike alarm (sementara)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => _guard('izin', () async {
                    await _svc.init();
                    final p = await _svc.requestPermissions();
                    return 'notifikasi=${p.notifications}, alarmTepat=${p.exactAlarm}';
                  }),
                  child: const Text('1. Init + izin'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => _guard(
                    '+60 dtk',
                    () => _schedule(1, const Duration(seconds: 60)),
                  ),
                  child: const Text('2. Alarm +60 dtk'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => _guard(
                    '+5 mnt',
                    () => _schedule(2, const Duration(minutes: 5)),
                  ),
                  child: const Text('3. Alarm +5 mnt'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => _guard('batal', () async {
                    await _svc.init();
                    await _svc.cancelAll();
                    return 'semua dibatalkan';
                  }),
                  child: const Text('Batalkan semua'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _log.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(_log[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}