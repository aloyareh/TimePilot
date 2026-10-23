import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Mengecilkan foto menjadi thumbnail persegi JPEG (default 128 px, +-5-8 KB)
/// untuk diunggah ke server. Fungsi top-level supaya bisa dipakai `compute`.
/// Mengembalikan null bila byte bukan gambar yang dikenali.
Uint8List? buildAvatarThumbnail(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final square = img.copyResizeCropSquare(upright, size: 128);
  return Uint8List.fromList(img.encodeJpg(square, quality: 72));
}