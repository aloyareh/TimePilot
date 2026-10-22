import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/data/local/models/feedback_entry.dart';

void main() {
  group('FeedbackEntry.fromJson', () {
    test('membaca semua field dan penanda milik sendiri', () {
      final e = FeedbackEntry.fromJson({
        'id': 'abc',
        'author': 'Raka',
        'impression': 'Bagus',
        'message': 'Tambah dark mode',
        'created_at': '2026-10-20T01:00:00Z',
        'updated_at': '2026-10-20T01:00:00Z',
        'is_mine': true,
      });
      expect(e.id, 'abc');
      expect(e.author, 'Raka');
      expect(e.isMine, isTrue);
      expect(e.isEdited, isFalse);
    });

    test('isEdited true bila updated_at jauh setelah created_at', () {
      final e = FeedbackEntry.fromJson({
        'id': 'abc',
        'impression': 'a',
        'message': 'b',
        'created_at': '2026-10-20T01:00:00Z',
        'updated_at': '2026-10-20T02:00:00Z',
      });
      expect(e.isEdited, isTrue);
      expect(e.author, 'Pengguna'); // fallback
      expect(e.isMine, isFalse); // default
    });
  });

  group('validateFeedbackField', () {
    test('kosong atau spasi saja ditolak', () {
      expect(validateFeedbackField('', label: 'Kesan'), isNotNull);
      expect(validateFeedbackField('   '), isNotNull);
      expect(validateFeedbackField(null), isNotNull);
    });

    test('maksimal 500 karakter', () {
      expect(validateFeedbackField('a' * 500), isNull);
      expect(validateFeedbackField('a' * 501), isNotNull);
    });
  });

  group('formatFeedbackTime', () {
    final now = DateTime(2026, 10, 22, 12, 0);
    test('rentang waktu relatif', () {
      expect(formatFeedbackTime(now, now: now), 'baru saja');
      expect(
        formatFeedbackTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 menit lalu',
      );
      expect(
        formatFeedbackTime(now.subtract(const Duration(hours: 3)), now: now),
        '3 jam lalu',
      );
      expect(
        formatFeedbackTime(now.subtract(const Duration(days: 2)), now: now),
        '2 hari lalu',
      );
    });

    test('lebih dari seminggu memakai tanggal', () {
      expect(formatFeedbackTime(DateTime(2026, 10, 1), now: now), '01/10/2026');
    });
  });
}
