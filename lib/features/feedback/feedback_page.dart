import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local/models/feedback_entry.dart';
import '../../data/repositories/feedback_repository.dart';
import 'feedback_providers.dart';

/// Tab "Kesan Pesan" (PBI-26): daftar kesan & pesan semua pengguna (Read),
/// tulis baru lewat tombol + (Create), dan ubah/hapus milik sendiri (Update/Delete).
class FeedbackPage extends ConsumerWidget {
  const FeedbackPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FeedbackEntry entry,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pesan?'),
        content: const Text('Pesan ini akan dihapus untuk semua pengguna.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await ref
        .read(feedbackListProvider.notifier)
        .delete(entry.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? 'Pesan dihapus.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(feedbackListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kesan Pesan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFeedbackForm(context),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Tulis'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedbackListProvider.notifier).refresh(),
        child: list.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            icon: Icons.cloud_off_outlined,
            text: e is FeedbackException ? e.message : 'Gagal memuat pesan.',
            action: FilledButton(
              onPressed: () => ref.invalidate(feedbackListProvider),
              child: const Text('Coba lagi'),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const _Message(
                icon: Icons.rate_review_outlined,
                text: 'Belum ada kesan & pesan.\nJadilah yang pertama menulis!',
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _FeedbackCard(
                entry: items[i],
                onEdit: () => showFeedbackForm(context, existing: items[i]),
                onDelete: () => _confirmDelete(context, ref, items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pesan di tengah layar yang tetap bisa ditarik untuk refresh.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 56, color: AppColors.blue),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action),
        ],
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final FeedbackEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = entry.author.isEmpty ? '?' : entry.author[0].toUpperCase();
    final time =
        formatFeedbackTime(entry.createdAt) +
        (entry.isEdited ? ' · diubah' : '');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 18, child: Text(initial)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.isMine ? '${entry.author} (kamu)' : entry.author,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(time, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (entry.isMine)
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Ubah')),
                      PopupMenuItem(value: 'delete', child: Text('Hapus')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kesan',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(entry.impression),
                  const SizedBox(height: 10),
                  Text(
                    'Pesan',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(entry.message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Membuka form di bottom sheet. Isi [existing] untuk mode ubah.
Future<void> showFeedbackForm(BuildContext context, {FeedbackEntry? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FeedbackFormSheet(existing: existing),
  );
}

class _FeedbackFormSheet extends ConsumerStatefulWidget {
  const _FeedbackFormSheet({this.existing});

  final FeedbackEntry? existing;

  @override
  ConsumerState<_FeedbackFormSheet> createState() => _FeedbackFormSheetState();
}

class _FeedbackFormSheetState extends ConsumerState<_FeedbackFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _impression = TextEditingController(
    text: widget.existing?.impression,
  );
  late final _message = TextEditingController(text: widget.existing?.message);
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _impression.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final notifier = ref.read(feedbackListProvider.notifier);
    final error = _isEdit
        ? await notifier.edit(
            widget.existing!.id,
            _impression.text,
            _message.text,
          )
        : await notifier.create(_impression.text, _message.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(_isEdit ? 'Pesan diperbarui.' : 'Pesan terkirim.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Ubah kesan & pesan' : 'Tulis kesan & pesan',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _impression,
                enabled: !_submitting,
                maxLines: 3,
                minLines: 2,
                maxLength: feedbackMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Kesan',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => validateFeedbackField(v, label: 'Kesan'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                enabled: !_submitting,
                maxLines: 3,
                minLines: 2,
                maxLength: feedbackMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Pesan',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => validateFeedbackField(v, label: 'Pesan'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Simpan perubahan' : 'Kirim'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
