import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/local/models/work_session.dart';
import '../profile/profile_providers.dart';
import '../session/session_money.dart';
import 'chain.dart';

/// Penyimpanan rantai di Hive (box 'chain'), satu entri JSON per blok.
class ChainRepository {
  ChainRepository(this.userId);

  /// Satu rantai per akun: kotak Hive dinamai dari ID pengguna.
  final String userId;

  String get _boxName => 'chain_${userId.replaceAll('-', '_')}';

  Future<Box<String>> _box() async => Hive.isBoxOpen(_boxName)
      ? Hive.box<String>(_boxName)
      : await Hive.openBox<String>(_boxName);

  Future<List<Block>> all() async {
    final box = await _box();
    final out = <Block>[];
    for (final raw in box.values) {
      try {
        out.add(Block.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Entri rusak dilewati; celah nomor urut akan terdeteksi saat verifikasi.
      }
    }
    out.sort((a, b) => a.index.compareTo(b.index));
    return out;
  }

  Future<void> put(Block b) async {
    final box = await _box();
    await box.put(b.index.toString().padLeft(8, '0'), jsonEncode(b.toJson()));
  }
}

/// null = belum login (tidak ada rantai).
final chainRepositoryProvider = Provider<ChainRepository?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return uid == null ? null : ChainRepository(uid);
});

class ChainNotifier extends AsyncNotifier<List<Block>> {
  @override
  Future<List<Block>> build() async {
    final repo = ref.watch(chainRepositoryProvider);
    return repo == null ? const <Block>[] : repo.all();
  }

  /// Menambah blok untuk sesi yang selesai. Idempotent: sesi yang sama tidak
  /// dicatat dua kali.
  Future<Block> addForSession(WorkSession s, SessionMoney money) async {
    final repo = ref.read(chainRepositoryProvider);
    if (repo == null) throw StateError('Belum login.');
    await future; // pastikan build() awal selesai agar tidak menimpa state kita
    final blocks = await repo.all();
    for (final b in blocks) {
      if (b.sessionId == s.id) return b;
    }
    final block = Block.create(
      prev: blocks.isEmpty ? null : blocks.last,
      endedAtUtc: s.endedAtUtc ?? DateTime.now().toUtc(),
      sessionId: s.id,
      taskId: s.taskId,
      clientId: s.clientId,
      durationSeconds: s.durationSeconds,
      lateMinutes: s.lateMinutes,
      currency: money.currency,
      netMinor: money.netMinor,
    );
    await repo.put(block);
    state = AsyncData([...blocks, block]);
    return block;
  }

  Future<void> reload() async {
    final repo = ref.read(chainRepositoryProvider);
    state = AsyncData(repo == null ? const <Block>[] : await repo.all());
  }
}

final chainProvider = AsyncNotifierProvider<ChainNotifier, List<Block>>(
  ChainNotifier.new,
);

void logChainError(Object e) => debugPrint('Blockchain: gagal mencatat blok: $e');