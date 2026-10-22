/// Satu kesan & pesan (tabel public.feedbacks di Supabase).
class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.author,
    required this.impression,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
    required this.isMine,
  });

  final String id;
  final String author;
  final String impression; // Kesan
  final String message; // Pesan
  final DateTime createdAt;
  final DateTime updatedAt;

  /// true bila ditulis oleh pengguna yang sedang login (boleh edit/hapus).
  final bool isMine;

  bool get isEdited => updatedAt.difference(createdAt).inSeconds > 1;

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) => FeedbackEntry(
    id: json['id'] as String,
    author: (json['author'] as String?) ?? 'Pengguna',
    impression: json['impression'] as String,
    message: json['message'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    isMine: (json['is_mine'] as bool?) ?? false,
  );
}

const feedbackMaxLength = 500;

/// Validator untuk kolom Kesan/Pesan. Mengembalikan null jika valid.
String? validateFeedbackField(String? value, {String label = 'Kolom'}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return '$label wajib diisi.';
  if (v.length > feedbackMaxLength) {
    return '$label maksimal $feedbackMaxLength karakter.';
  }
  return null;
}

/// "baru saja", "5 menit lalu", "3 jam lalu", "2 hari lalu", lalu dd/mm/yyyy.
String formatFeedbackTime(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
  if (diff.inDays < 1) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.day)}/${two(time.month)}/${time.year}';
}
