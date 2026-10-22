import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_service.dart';

/// Membungkus layar utama: sinkron otomatis saat masuk dan saat aplikasi kembali
/// dibuka (paling cepat tiap 30 detik). Letakkan di dalam AuthGate.
class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle>
    with WidgetsBindingObserver {
  DateTime? _last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _auto());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _auto();
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