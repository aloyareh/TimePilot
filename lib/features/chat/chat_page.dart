import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'chat_providers.dart';
import 'chat_service.dart';

/// Chatbot AI (PBI-24): tanya jawab dengan Gemini.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _suggestions = [
    'Bagaimana cara menentukan tarif per jam?',
    'Tips menagih klien yang telat bayar',
    'Atur jadwal kerja dengan klien beda zona waktu',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatProvider.notifier).send(text);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    ref.listen<ChatState>(chatProvider, (prev, next) => _scrollToEnd());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanya Asisten'),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus percakapan',
              onPressed: chat.sending
                  ? null
                  : ref.read(chatProvider.notifier).clear,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: chat.messages.isEmpty
                  ? _Empty(onPick: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          chat.messages.length + (chat.sending ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == chat.messages.length) {
                          return const _Bubble(
                            fromUser: false,
                            child: SizedBox(
                              width: 36,
                              height: 12,
                              child: LinearProgressIndicator(),
                            ),
                          );
                        }
                        final m = chat.messages[i];
                        return _Bubble(
                          fromUser: m.fromUser,
                          child: SelectableText(m.text),
                        );
                      },
                    ),
            ),
            if (chat.error != null)
              Container(
                width: double.infinity,
                color: AppColors.error.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    TextButton(
                      onPressed: ref.read(chatProvider.notifier).retry,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !chat.sending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(
                        hintText: 'Tulis pertanyaan…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    tooltip: 'Kirim',
                    onPressed: chat.sending ? null : () => _send(_input.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onPick});

  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.orange),
            const SizedBox(height: 12),
            Text(
              'Tanya apa saja soal kerja freelance',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            for (final s in _ChatPageState._suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ActionChip(label: Text(s), onPressed: () => onPick(s)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.fromUser, required this.child});

  final bool fromUser;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxW = MediaQuery.sizeOf(context).width * 0.8;
    // Pengguna: biru tua pekat, teks putih. AI: abu terang dengan garis tepi, teks gelap.
    final bg = fromUser ? AppColors.navy : scheme.surfaceContainerHighest;
    final fg = fromUser ? Colors.white : scheme.onSurface;
    const r = Radius.circular(16);
    const tail = Radius.circular(4);
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: maxW),
        decoration: BoxDecoration(
          color: bg,
          border: fromUser ? null : Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: fromUser ? r : tail,
            bottomRight: fromUser ? tail : r,
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: fg, height: 1.35),
          child: child,
        ),
      ),
    );
  }
}