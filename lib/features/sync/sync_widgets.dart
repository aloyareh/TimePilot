import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_service.dart';

/// Membungkus layar utama: sinkron otomatis saat masuk dan saat aplikasi kembali
/// dibuka (paling cepat tiap 30 detik). Selama app terbuka, ada pengecek tiap 20 detik:
/// bila sinkron terakhir gagal (mis. offline) ia mencoba lagi, bila tidak ia sinkron
/// ulang tiap 2 menit. Letakkan di dalam AuthGate.
class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle>
    with WidgetsBindingObserver {
  DateTime? _last;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _auto());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _auto();
  }

  bool _foreground = true;

  void _tick() {
    if (!_foreground) return;
    final s = ref.read(syncProvider);
    if (s.syncing) return;
    final age = s.lastSyncAt == null
        ? const Duration(days: 1)
        : DateTime.now().difference(s.lastSyncAt!);
    // Gagal terakhir kali (offline): coba lagi tiap tick. Selain itu tiap 2 menit.
    if (s.error != null || age >= const Duration(minutes: 2)) {
      _last = DateTime.now();
      ref.read(syncProvider.notifier).sync();
    }
  }

  void _auto() {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < const Duration(seconds: 30)) return;
    _last = now;
    ref.read(syncProvider.notifier).sync();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Tombol sinkron manual untuk AppBar, dengan ikon status.
class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncProvider);
    if (s.syncing) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: Icon(s.error != null ? Icons.sync_problem : Icons.cloud_sync_outlined),
      tooltip: 'Sinkronkan',
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        await ref.read(syncProvider.notifier).sync();
        final r = ref.read(syncProvider);
        final text = r.error != null
            ? r.error!
            : 'Sinkron selesai: ${r.last?.pushed ?? 0} dikirim, ${r.last?.pulled ?? 0} diterima.';
        messenger.showSnackBar(SnackBar(content: Text(text)));
      },
    );
  }
}