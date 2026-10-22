import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/models/feedback_entry.dart';
import '../../data/repositories/feedback_repository.dart';
import '../auth/auth_controller.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FeedbackRepository(),
);

final feedbackListProvider =
    AsyncNotifierProvider<FeedbackListNotifier, List<FeedbackEntry>>(
      FeedbackListNotifier.new,
    );

class FeedbackListNotifier extends AsyncNotifier<List<FeedbackEntry>> {
  FeedbackRepository get _repo => ref.read(feedbackRepositoryProvider);

  @override
  Future<List<FeedbackEntry>> build() async {
    // Ikut berganti saat user login/logout, supaya penanda "milikku" (is_mine)
    // dari akun sebelumnya tidak tersisa.
    final userId = ref.watch(authControllerProvider.select((a) => a.value?.id));
    if (userId == null) return const [];
    return _repo.list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.list);
  }

  /// Mengembalikan pesan error, atau null bila berhasil.
  Future<String?> create(String impression, String message) =>
      _mutate(() => _repo.create(impression: impression, message: message));

  Future<String?> edit(String id, String impression, String message) =>
      _mutate(
        () => _repo.update(id: id, impression: impression, message: message),
      );

  Future<String?> delete(String id) => _mutate(() => _repo.delete(id));

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } on FeedbackException catch (e) {
      return e.message;
    }
    await refresh();
    return null;
  }
}
