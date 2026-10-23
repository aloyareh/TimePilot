import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/photo_remote.dart';
import 'feedback_providers.dart';

/// Foto penulis tiap kesan & pesan (kunci = id kesan). Diambil ulang setiap
/// daftar kesan & pesan dimuat ulang.
final feedbackPhotosProvider = FutureProvider<Map<String, Uint8List>>((
  ref,
) async {
  await ref.watch(feedbackListProvider.future);
  return ref.read(photoRemoteProvider).fetchForFeedbacks();
});