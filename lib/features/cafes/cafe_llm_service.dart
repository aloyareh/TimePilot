import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../core/env.dart';

class Cafe {
  const Cafe({
    required this.name,
    required this.type,
    required this.area,
    required this.note,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String type;
  final String area;
  final String note;
  final double? latitude;
  final double? longitude;

  Cafe withNote(String n) => Cafe(
    name: name,
    type: type,
    area: area,
    note: n,
    latitude: latitude,
    longitude: longitude,
  );
}

/// AI hanya MENJELASKAN tempat yang sudah ditemukan di peta (PBI-25); ia tidak lagi
/// diminta mengarang daftar tempat dari koordinat. Bila AI gagal (kunci kosong,
/// ditolak, offline), daftar dari peta tetap tampil.
class CafeLlmService {
  static const modelName = 'gemini-2.5-flash';

  /// Mengembalikan satu catatan singkat per tempat (urutan sama). Melempar
  /// exception bila gagal; pemanggil yang menangkapnya.
  Future<List<String>> annotate(List<Cafe> places) async {
    if (Env.geminiApiKey.isEmpty) throw StateError('GEMINI_API_KEY kosong.');
    if (places.isEmpty) return const [];

    final model = GenerativeModel(
      model: modelName,
      apiKey: Env.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        responseMimeType: 'application/json',
      ),
    );
    final list = [
      for (var i = 0; i < places.length; i++)
        {'i': i, 'name': places[i].name, 'type': places[i].type, 'data': places[i].note},
    ];
    final prompt =
        '''
Kamu asisten untuk freelancer yang mencari tempat kerja.
Berikut tempat NYATA dari peta (JSON): ${jsonEncode(list)}
Untuk tiap tempat tulis 1 kalimat Bahasa Indonesia (maks 18 kata) tentang
kecocokannya untuk bekerja, HANYA berdasarkan nama, jenis, dan field "data".
Jangan menambah fakta (harga, menu, suasana) yang tidak ada di data.
Jawab HANYA JSON array: [{"i": 0, "note": "..."}, ...]
''';
    final res = await model
        .generateContent([Content.text(prompt)])
        .timeout(const Duration(seconds: 25));
    final text = res.text;
    if (text == null || text.trim().isEmpty) {
      throw StateError('AI tidak mengembalikan jawaban.');
    }
    final decoded = jsonDecode(text.replaceAll(RegExp(r'```(?:json)?'), '').trim());
    if (decoded is! List) throw const FormatException('Format jawaban AI tidak sesuai.');
    final out = List<String>.filled(places.length, '');
    for (final e in decoded) {
      if (e is Map && e['i'] is int && e['note'] != null) {
        final i = e['i'] as int;
        if (i >= 0 && i < out.length) out[i] = e['note'].toString().trim();
      }
    }
    return out;
  }
}