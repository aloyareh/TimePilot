import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import 'profile_photo_providers.dart';

/// Avatar pengguna. Bila [editable], ketukan membuka menu ubah foto
/// (kamera, galeri, hapus).
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({super.key, this.radius = 28, this.editable = false});

  final double radius;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(profilePhotoProvider).value;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.navy,
      backgroundImage: photo == null ? null : FileImage(photo),
      child: photo == null
          ? Icon(Icons.person_rounded, color: Colors.white, size: radius)
          : null,
    );

    if (!editable) {
      return avatar;
    }

    return Semantics(
      button: true,
      label: 'Ubah foto profil',
      child: GestureDetector(
        onTap: () => showProfilePhotoSheet(context, ref),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            Positioned(
              right: -2,
              bottom: -2,
              child: CircleAvatar(
                radius: radius * 0.36,
                backgroundColor: AppColors.blue,
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: radius * 0.38,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menu bawah: ambil dari kamera, pilih dari galeri, atau hapus foto.
Future<void> showProfilePhotoSheet(BuildContext context, WidgetRef ref) async {
  final hasPhoto = ref.read(profilePhotoProvider).value != null;
  final action = await showModalBottomSheet<_PhotoAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil foto'),
            onTap: () => Navigator.of(ctx).pop(_PhotoAction.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(hasPhoto ? 'Ganti dari galeri' : 'Pilih dari galeri'),
            onTap: () => Navigator.of(ctx).pop(_PhotoAction.gallery),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Hapus foto',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.of(ctx).pop(_PhotoAction.delete),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) {
    return;
  }

  switch (action) {
    case _PhotoAction.camera:
      await _pick(context, ref, ImageSource.camera);
    case _PhotoAction.gallery:
      await _pick(context, ref, ImageSource.gallery);
    case _PhotoAction.delete:
      await _confirmDelete(context, ref);
  }
}

enum _PhotoAction { camera, gallery, delete }

Future<void> _pick(
  BuildContext context,
  WidgetRef ref,
  ImageSource source,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) {
      return; // dibatalkan
    }
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Atur foto profil',
          toolbarColor: AppColors.navy,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.blue,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          hideBottomControls: true,
        ),
      ],
    );
    if (cropped == null) {
      return;
    }
    await ref.read(profilePhotoProvider.notifier).setFromPath(cropped.path);
    messenger.showSnackBar(
      const SnackBar(content: Text('Foto profil diperbarui.')),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          source == ImageSource.camera
              ? 'Kamera tidak bisa dibuka. Periksa izin kamera.'
              : 'Galeri tidak bisa dibuka.',
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus foto profil?'),
      content: const Text('Avatar akan kembali ke ikon default.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (ok != true) {
    return;
  }
  await ref.read(profilePhotoProvider.notifier).remove();
  messenger.showSnackBar(const SnackBar(content: Text('Foto profil dihapus.')));
}
