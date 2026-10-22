import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/local/models/client.dart';
import '../../data/local/models/task.dart';
import '../../data/local/models/work_session.dart';
import '../profile/profile_providers.dart';
import '../session/session_money.dart';
import '../session/session_providers.dart';

/// Ringkasan pendapatan satu klien (PBI-20). Angka dalam mata uang klien.
class ClientEarnings {
  const ClientEarnings({
    required this.clientId,
    required this.clientName,
    required this.currency,
    required this.sessionCount,
    required this.totalSeconds,
    required this.lateMinutes,
    required this.gross,
    required this.penalty,
    required this.net,
  });

  final String clientId;
  final String clientName;
  final String currency;
  final int sessionCount;
  final int totalSeconds;
  final int lateMinutes;
  final double gross;
  final double penalty;
  final double net;
}

/// Fungsi murni: mengelompokkan sesi SELESAI per klien dan menjumlahkan uangnya.
/// Setiap sesi dihitung sendiri (denda per sesi, bersih tidak negatif per sesi),
/// jadi satu sesi yang sangat terlambat tidak mengurangi sesi lain.
/// Klien yang tidak ditemukan dihitung dengan tarif 0.
List<ClientEarnings> buildEarnings(
  List<WorkSession> sessions,
  Map<String, Client> clients,
) {
  final groups = <String, List<WorkSession>>{};
  for (final s in sessions) {
    if (s.endedAtUtc == null || s.isDeleted) continue;
    groups.putIfAbsent(s.clientId, () => []).add(s);
  }
  final out = <ClientEarnings>[];
  groups.forEach((clientId, list) {
    final c = clients[clientId];
    final currency = c?.currency ?? 'IDR';
    var gross = 0.0, penalty = 0.0, net = 0.0;
    var seconds = 0, late = 0;
    for (final s in list) {
      final m = computeSessionMoney(
        durationSeconds: s.durationSeconds,
        lateMinutes: s.lateMinutes,
        hourlyRate: c?.hourlyRate ?? 0,
        currency: currency,
      );
      gross += m.gross;
      penalty += m.penalty;
      net += m.net;
      seconds += s.durationSeconds;
      late += s.lateMinutes;
    }
    out.add(
      ClientEarnings(
        clientId: clientId,
        clientName: c?.name ?? 'Klien tidak ditemukan',
        currency: currency,
        sessionCount: list.length,
        totalSeconds: seconds,
        lateMinutes: late,
        gross: gross,
        penalty: penalty,
        net: net,
      ),
    );
  });
  out.sort((a, b) => b.net.compareTo(a.net));
  return out;
}

/// Pendapatan pengguna yang sedang login. Sesi diturunkan kepemilikannya dari
/// tugasnya (WorkSession belum punya ownerId). Kotak Hive dibaca langsung agar
/// tugas dan klien yang sudah dihapus (soft delete) tetap terhitung.
final earningsProvider = Provider<List<ClientEarnings>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  ref.watch(sessionProvider); // hitung ulang saat sesi selesai
  if (uid == null) return const [];
  final tasks = Hive.box<Task>(HiveBoxes.tasks);
  final clientBox = Hive.box<Client>(HiveBoxes.clients);
  final sessions = ref
      .read(workSessionRepositoryProvider)
      .getAll()
      .where((s) => s.endedAtUtc != null && tasks.get(s.taskId)?.ownerId == uid)
      .toList();
  final clients = {
    for (final c in clientBox.values)
      if (c.ownerId == uid) c.id: c,
  };
  return buildEarnings(sessions, clients);
});