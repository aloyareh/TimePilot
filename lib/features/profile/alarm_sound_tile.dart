import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/alarm_sound.dart';
import '../../core/theme/app_theme.dart';
import 'alarm_sound_provider.dart';

enum _SoundAction { import, preview, reset }

/// Baris pengaturan "Suara alarm" untuk halaman Profil.
class AlarmSoundTile extends ConsumerStatefulWidget {
  const AlarmSoundTile({super.key});

  @override
  ConsumerState<AlarmSoundTile> createState() => _AlarmSoundTileState();
}

class _AlarmSoundTileState extends ConsumerState<AlarmSoundTile> {
  @override
  void dispose() {
    AlarmSoundChannel.stopPreview().catchError((_) {});
    super.dispose();
  }

  Future<void> _onAction(_SoundAction action, AlarmSound? sound) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(alarmSoundProvider.notifier);
    switch (action) {
      case _SoundAction.import:
        final error = await notifier.importSound();
        messenger.showSnackBar(
          SnackBar(
            content: Text(error ?? 'Suara alarm diperbarui.'),
          ),
        );
      case _SoundAction.preview:
        if (sound != null) {
          try {
            await AlarmSoundChannel.preview(sound.uri);
          } catch (_) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Suara tidak bisa diputar.')),
            );
          }
        }
      case _SoundAction.reset:
        await notifier.reset();
        messenger.showSnackBar(
          const SnackBar(content: Text('Kembali ke suara default.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sound = ref.watch(alarmSoundProvider).value;
    return ListTile(
      leading: const Icon(Icons.music_note_outlined, color: AppColors.navy),
      title: const Text('Suara alarm'),
      subtitle: Text(
        sound?.name ?? 'Default',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<_SoundAction>(
        onSelected: (a) => _onAction(a, sound),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: _SoundAction.import,
            child: Text('Impor dari file'),
          ),
          if (sound != null) ...const [
            PopupMenuItem(value: _SoundAction.preview, child: Text('Pratinjau')),
            PopupMenuItem(
              value: _SoundAction.reset,
              child: Text('Kembali ke default'),
            ),
          ],
        ],
      ),
      onTap: () => _onAction(_SoundAction.import, sound),
    );
  }
}