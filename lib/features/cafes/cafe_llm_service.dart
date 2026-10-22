import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../core/env.dart';

class Cafe {
  const Cafe({
    required this.name,
    required this.type,
    required this.area,
    required this.note,
  });

  final String name;
  final String type;
  final String area;
  final String note;

  factory Cafe.fromJson(Map<String, dynamic> j) => Cafe(
    name: (j['name'] ?? '').toString().trim(),
    type: (j['type'] ?? 'Kafe').toString().trim(),
    area: (j['area'] ?? '').toString().trim(),
    note: (j['note'] ?? '').toString().trim(),
  );
}

/// Rekomendasi kafe/coworking berbasis koordinat lewat Gemini (PBI-25).
class CafeLlmService {
  static const _modelName = 'gemini-3.8-flash';

  Future<List<Cafe>> recommend({
    required double latitude,
    required double longitude,
  }) async {
    if (Env.geminiApiKey.isEmpty) {
      throw StateError(
        'GEMINI_API_KEY kosong. '
        'Jalankan: flutter run --dart-define-from-file=env.json',
      );
    }

    final model = GenerativeModel(
      model: _modelName,
      apiKey: Env.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        responseMimeType: 'application/json',
      ),
    );

    final prompt =
        '''
Kamu asisten untuk freelancer yang mencari tempat kerja.
Koordinat pengguna: latitude $latitude, longitude $longitude.
Sebutkan maksimal 5 kafe atau coworking space NYATA yang kamu ketahui berada
di sekitar koordinat tersebut dan cocok untuk bekerja (wifi, colokan, tenang).
Jangan mengarang nama tempat. Jika tidak yakin, kembalikan array kosong [].
Jawab HANYA JSON array tanpa teks lain, setiap elemen berbentuk:
{"name": "nama tempat", "type": "Kafe atau Coworking", "area": "kecamatan/jalan", "note": "alasan cocok untuk kerja, 1 kalimat Bahasa Indonesia"}
''';

    final res = await model
        .generateContent([Content.text(prompt)])
        .timeout(const Duration(seconds: 30));

    final text = res.text;
    if (text == null || text.trim().isEmpty) {
      throw StateError('AI tidak mengembalikan jawaban.');
    }

    final clean = text.replaceAll(RegExp(r'```(?:json)?'), '').trim();
    final decoded = jsonDecode(clean);
    final raw = decoded is List
        ? decoded
        : (decoded is Map ? decoded['cafes'] : null);
    if (raw is! List) {
      throw const FormatException('Format jawaban AI tidak sesuai.');
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map(Cafe.fromJson)
        .where((c) => c.name.isNotEmpty)
        .take(6)
        .toList();
  }
}
