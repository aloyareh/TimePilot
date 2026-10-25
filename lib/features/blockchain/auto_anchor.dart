import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'anchor_section.dart';
import 'anchor_service.dart';
import 'chain_repository.dart';

/// Menjangkarkan blok baru ke blockchain secara otomatis (tanpa pengguna
/// menekan tombol), dipanggil setelah sinkronisasi berhasil. Best-effort:
/// gagal diam-diam dan baru dicoba lagi setelah jeda.
class AutoAnchor {
  AutoAnchor(this._ref);

  final Ref _ref;
  bool _running = false;
  DateTime? _blockedUntil;

  Future<void> maybeAnchor() async {
    if (_running) return;
    final until = _blockedUntil;
    if (until != null && DateTime.now().isBefore(until)) return;

    final blocks = _ref.read(chainProvider).value;
    if (blocks == null || blocks.isEmpty) return;

    _running = true;
    try {
      final service = _ref.read(anchorServiceProvider);
      final anchors = await service.list();
      final latest = anchors.isEmpty ? -1 : anchors.first.uptoIdx;
      if (blocks.length - 1 <= latest) return; // semua blok sudah dijangkarkan
      await service.anchorNow();
      _blockedUntil = null;
    } on AnchorException catch (e) {
      // Saldo habis / wallet belum diatur: tidak perlu dicoba tiap menit.
      final long = e.code == 'WALLET_EMPTY' || e.code == 'WALLET_NOT_CONFIGURED';
      _blockedUntil = DateTime.now().add(
        long ? const Duration(minutes: 30) : const Duration(minutes: 5),
      );
    } catch (_) {
      _blockedUntil = DateTime.now().add(const Duration(minutes: 5));
    } finally {
      _running = false;
    }
  }
}

final autoAnchorProvider = Provider<AutoAnchor>((ref) => AutoAnchor(ref));