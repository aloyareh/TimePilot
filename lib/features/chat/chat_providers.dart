import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_providers.dart';
import 'chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

class ChatState {
  const ChatState({this.messages = const [], this.sending = false, this.error});

  final List<ChatMessage> messages;
  final bool sending;

  /// Pesan kesalahan untuk pengguna; pesan terakhir pengguna tetap ada agar
  /// bisa dicoba lagi.
  final String? error;
}

/// Percakapan disimpan di memori per pengguna: ganti akun atau logout menghapusnya.
class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    ref.watch(currentUserIdProvider);
    return const ChatState();
  }

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || state.sending) return;
    state = ChatState(
      messages: [...state.messages, ChatMessage(text: t, fromUser: true)],
      sending: true,
    );
    await _ask();
  }

  /// Mengulang permintaan terakhir setelah gagal.
  Future<void> retry() async {
    if (state.sending || state.messages.isEmpty || !state.messages.last.fromUser) {
      return;
    }
    state = ChatState(messages: state.messages, sending: true);
    await _ask();
  }

  void clear() => state = const ChatState();

  Future<void> _ask() async {
    final sentFor = ref.read(currentUserIdProvider);
    final history = state.messages;
    final profile = ref.read(profileProvider);
    try {
      final answer = await ref
          .read(chatServiceProvider)
          .reply(
            history,
            buildSystemPrompt(
              role: profile?.role,
              timezone: profile?.homeTimezone,
              currency: profile?.mainCurrency,
            ),
          );
      // Pengguna ganti akun atau menghapus percakapan saat menunggu: buang jawabannya.
      if (!ref.mounted || sentFor != ref.read(currentUserIdProvider)) return;
      if (state.messages.length != history.length) return;
      state = ChatState(
        messages: [...history, ChatMessage(text: answer, fromUser: false)],
      );
    } catch (_) {
      if (!ref.mounted || state.messages.length != history.length) return;
      state = ChatState(
        messages: history,
        error: 'Asisten sedang tidak bisa menjawab. '
            'Periksa koneksi internet lalu coba lagi.',
      );
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);