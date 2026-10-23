import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local/models/feedback_entry.dart';
import '../../data/repositories/feedback_repository.dart';
import '../profile/profile_avatar.dart';
import 'feedback_photo_provider.dart';
import 'feedback_providers.dart';

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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(96, 44),
            ),
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
    final photos = ref.watch(feedbackPhotosProvider).value ?? const <String, Uint8List>{};

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
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s16,
                96,
              ),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.s12),
              itemBuilder: (context, i) {
                if (i == 0) return const _FeedbackIntro();
                final entry = items[i - 1];
                return _FeedbackCard(
                  entry: entry,
                  photo: photos[entry.id],
                  onEdit: () => showFeedbackForm(context, existing: entry),
                  onDelete: () => _confirmDelete(context, ref, entry),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FeedbackIntro extends StatelessWidget {
  const _FeedbackIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kesan & Pesan', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'Bagikan pengalamanmu agar TimePilot makin baik.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.s32),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 56, color: AppColors.navInactive),
        const SizedBox(height: AppSpacing.s12),
        Text(text, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: AppSpacing.s16),
          Center(child: action),
        ],
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.entry,
    required this.photo,
    required this.onEdit,
    required this.onDelete,
  });

  final FeedbackEntry entry;
  final Uint8List? photo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Satu bagian isi kartu: garis warna di kiri, judul kecil, lalu teks.
  Widget _block(
    ThemeData theme, {
    required String label,
    required Color color,
    required String text,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.navInactive,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = entry.author.isEmpty ? '?' : entry.author[0].toUpperCase();
    final time =
        formatFeedbackTime(entry.createdAt) +
        (entry.isEdited ? ' \u00B7 diubah' : '');

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s8,
        AppSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r24),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Kartu milikmu memakai foto lokal; kartu orang lain memakai
              // thumbnail dari server, atau inisial bila belum punya foto.
              if (entry.isMine)
                const ProfileAvatar(radius: 20)
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.navy,
                  backgroundImage: photo == null ? null : MemoryImage(photo!),
                  child: photo != null
                      ? null
                      : Text(
                          initial,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.isMine ? '${entry.author} (kamu)' : entry.author,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(time, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (entry.isMine)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz,
                    color: AppColors.navInactive,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.r12),
                  ),
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Ubah')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _block(
                  theme,
                  label: 'Kesan',
                  color: AppColors.navy,
                  text: entry.impression,
                ),
                const SizedBox(height: AppSpacing.s12),
                _block(
                  theme,
                  label: 'Pesan',
                  color: AppColors.orange,
                  text: entry.message,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showFeedbackForm(BuildContext context, {FeedbackEntry? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r24)),
    ),
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
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s16 + MediaQuery.of(context).viewInsets.bottom,
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
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Bantu kami membuat TimePilot lebih baik.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.s16),
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
                ),
                validator: (v) => validateFeedbackField(v, label: 'Kesan'),
              ),
              const SizedBox(height: AppSpacing.s12),
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
                ),
                validator: (v) => validateFeedbackField(v, label: 'Pesan'),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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