import '../../data/local/models/client.dart';
import '../../data/local/models/profile.dart';
import '../../data/local/models/task.dart';
import '../../data/local/models/work_session.dart';
import '../blockchain/chain.dart';

/// Pemetaan model lokal <-> JSON untuk RPC sinkronisasi (PBI-22). Fungsi murni.

Map<String, dynamic> taskToJson(Task t) => {
  'id': t.id,
  'title': t.title,
  'client_id': t.clientId,
  'deadline_utc': t.deadlineUtc.toUtc().toIso8601String(),
  'status': t.status,
  'created_at': t.createdAt.toUtc().toIso8601String(),
  'updated_at': t.updatedAt.toUtc().toIso8601String(),
  'is_deleted': t.isDeleted,
};

Task taskFromJson(Map<String, dynamic> j, String ownerId) => Task(
  id: j['id'] as String,
  title: j['title'] as String,
  clientId: j['client_id'] as String,
  deadlineUtc: DateTime.parse(j['deadline_utc'] as String).toUtc(),
  status: j['status'] as String,
  createdAt: DateTime.parse(j['created_at'] as String).toUtc(),
  updatedAt: DateTime.parse(j['updated_at'] as String).toUtc(),
  isDeleted: (j['is_deleted'] as bool?) ?? false,
  ownerId: ownerId,
);

Map<String, dynamic> sessionToJson(WorkSession s) => {
  'id': s.id,
  'task_id': s.taskId,
  'client_id': s.clientId,
  'started_at_utc': s.startedAtUtc.toUtc().toIso8601String(),
  'ended_at_utc': s.endedAtUtc?.toUtc().toIso8601String(),
  'duration_seconds': s.durationSeconds,
  'late_minutes': s.lateMinutes,
  'updated_at': s.updatedAt.toUtc().toIso8601String(),
  'is_deleted': s.isDeleted,
};

WorkSession sessionFromJson(Map<String, dynamic> j) => WorkSession(
  id: j['id'] as String,
  taskId: j['task_id'] as String,
  clientId: j['client_id'] as String,
  startedAtUtc: DateTime.parse(j['started_at_utc'] as String).toUtc(),
  endedAtUtc: j['ended_at_utc'] == null
      ? null
      : DateTime.parse(j['ended_at_utc'] as String).toUtc(),
  durationSeconds: (j['duration_seconds'] as num?)?.toInt() ?? 0,
  lateMinutes: (j['late_minutes'] as num?)?.toInt() ?? 0,
  updatedAt: DateTime.parse(j['updated_at'] as String).toUtc(),
  isDeleted: (j['is_deleted'] as bool?) ?? false,
);

/// Last-write-wins: data dari server menimpa data lokal hanya jika lebih baru.
/// Waktu yang sama = pertahankan data lokal.
bool shouldApplyRemote(DateTime? localUpdatedAt, DateTime remoteUpdatedAt) =>
    localUpdatedAt == null || remoteUpdatedAt.isAfter(localUpdatedAt);

/// Hasil perbandingan rantai lokal dengan salinan di server.
class ChainCheck {
  const ChainCheck({
    required this.localCount,
    required this.serverCount,
    required this.mismatched,
    required this.missingOnServer,
    required this.serverOnly,
  });

  final int localCount;
  final int serverCount;

  /// Nomor blok yang ada di kedua sisi tetapi hash-nya BERBEDA (tanda manipulasi).
  final List<int> mismatched;

  /// Blok lokal yang belum ada di server (belum tersinkron).
  final List<int> missingOnServer;

  /// Blok di server yang tidak ada di lokal (data lokal hilang atau terpotong).
  final List<int> serverOnly;

  bool get consistent =>
      mismatched.isEmpty && serverOnly.isEmpty && missingOnServer.isEmpty;
}

/// Sisi lokal dibandingkan memakai hash yang DIHITUNG ULANG dari isi blok, bukan
/// hash yang tersimpan, supaya blok yang isinya diubah tanpa hash baru juga
/// ketahuan. Sisi server memakai hash tersimpan (server sudah memverifikasinya).
ChainCheck diffChains(List<Block> local, List<Block> server) {
  final l = {for (final b in local) b.index: b.recompute()};
  final s = {for (final b in server) b.index: b.hash};
  final mismatched = <int>[], missing = <int>[], serverOnly = <int>[];
  l.forEach((i, h) {
    if (!s.containsKey(i)) {
      missing.add(i);
    } else if (s[i] != h) {
      mismatched.add(i);
    }
  });
  s.keys.where((i) => !l.containsKey(i)).forEach(serverOnly.add);
  mismatched.sort();
  missing.sort();
  serverOnly.sort();
  return ChainCheck(
    localCount: local.length,
    serverCount: server.length,
    mismatched: mismatched,
    missingOnServer: missing,
    serverOnly: serverOnly,
  );
}

// ------------------------------------------------------------ profil dan klien

Profile profileFromJson(Map<String, dynamic> j, String userId) => Profile(
  id: userId,
  role: j['role'] as String,
  homeTimezone: j['home_timezone'] as String,
  mainCurrency: j['main_currency'] as String,
  workStartMinutes: (j['work_start_minutes'] as num).toInt(),
  workEndMinutes: (j['work_end_minutes'] as num).toInt(),
  challengeType: j['challenge_type'] as String,
  challengeDifficulty: (j['challenge_difficulty'] as num).toInt(),
  updatedAt: DateTime.parse(j['updated_at'] as String).toUtc(),
);

Client clientFromJson(Map<String, dynamic> j, String ownerId) => Client(
  id: j['id'] as String,
  name: j['name'] as String,
  timezoneId: j['timezone_id'] as String,
  hourlyRate: (j['hourly_rate'] as num).toDouble(),
  currency: j['currency'] as String,
  updatedAt: DateTime.parse(j['updated_at'] as String).toUtc(),
  isDeleted: (j['is_deleted'] as bool?) ?? false,
  ownerId: ownerId,
);

/// Rencana dorong klien lokal ke server. Server (app_save_client) menimpa tanpa
/// memeriksa waktu, jadi keputusan "siapa lebih baru" dibuat di sini SETELAH
/// data server ditarik: hanya klien lokal yang LEBIH BARU dari versi server
/// (atau belum ada di server) yang dikirim.
class ClientPushPlan {
  const ClientPushPlan({required this.save, required this.deleteIds});

  final List<Client> save;
  final List<String> deleteIds;
}

ClientPushPlan planClientPush(
  List<Client> localOwned,
  Map<String, DateTime> remoteUpdatedAt,
  Set<String> remoteDeleted,
) {
  final save = <Client>[];
  final deleteIds = <String>[];
  for (final c in localOwned) {
    final r = remoteUpdatedAt[c.id];
    if (c.isDeleted) {
      // Hapus di server hanya jika server masih menyimpannya sebagai aktif
      // dan penghapusan lokal lebih baru.
      if (r != null && !remoteDeleted.contains(c.id) && c.updatedAt.isAfter(r)) {
        deleteIds.add(c.id);
      }
    } else if (r == null || c.updatedAt.isAfter(r)) {
      save.add(c);
    }
  }
  return ClientPushPlan(save: save, deleteIds: deleteIds);
}