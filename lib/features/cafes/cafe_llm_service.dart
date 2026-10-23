import 'dart:convert';

import 'package:http/http.dart' as http;

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
///
/// Memanggil REST generateContent langsung (bukan paket google_generative_ai) agar
/// jawaban model baru yang memuat "thoughtSignature"/bagian pikiran tidak merusak
/// pembacaan, dan kunci dikirim lewat header, bukan URL.
class CafeLlmService {
  CafeLlmService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Dicoba berurutan; model lite menjawab ~2 detik, gemini-3.8-flash ~30 detik
  /// (diukur dengan kunci proyek ini). Yang berikutnya dipakai bila yang sebelumnya
  /// gagal atau melewati batas waktu.
  static const models = [
    (name: 'gemini-3.5-flash-lite', timeout: Duration(seconds: 25)),
    (name: 'gemini-3.1-flash-lite', timeout: Duration(seconds: 25)),
    (name: 'gemini-3.8-flash', timeout: Duration(seconds: 75)),
  ];

  /// Mengembalikan ringkasan rekomendasi + catatan per tempat (urutan sama; catatan
  /// kosong bila datanya tidak cukup). Melempar exception bila gagal.
  Future<CafeAi> annotate(List<Cafe> places) async {
    if (Env.geminiApiKey.isEmpty) throw StateError('GEMINI_API_KEY kosong.');
    if (places.isEmpty) return const CafeAi(summary: '', notes: []);

    // Hanya 6 tempat terdekat yang diberi catatan: prompt lebih pendek, jawaban lebih cepat.
    final sent = places.take(6).toList();
    final list = [
      for (var i = 0; i < sent.length; i++)
        {
          'i': i,
          'name': sent[i].name,
          'type': sent[i].type,
          'area': sent[i].area,
          'data': sent[i].note,
        },
    ];
    final prompt =
        '''
Kamu asisten untuk freelancer yang mencari tempat kerja.
Tempat NYATA dari peta (JSON): ${jsonEncode(list)}
"area" berisi jarak dari pengguna dan jalan; "data" berisi WiFi/jam buka bila ada.
Tugas:
1. "summary": 1-2 kalimat Bahasa Indonesia yang merekomendasikan tempat paling
   layak dicoba untuk bekerja, menyebut namanya, berdasarkan jarak, WiFi, dan jam
   buka. Bila data terlalu sedikit untuk membedakan, katakan jujur bahwa datanya
   terbatas dan sarankan memastikan WiFi dan colokan di lokasi.
2. "notes": untuk tempat yang field "data"-nya BERISI informasi, 1 kalimat singkat
   (maks 18 kata) yang memakai informasi itu. Untuk tempat yang "data"-nya kosong,
   isi "note" dengan "" (jangan menulis kalimat umum).
Jangan menambah fakta (harga, menu, suasana) di luar data.
Jawab HANYA JSON: {"summary": "...", "notes": [{"i": 0, "note": "..."}]}
''';

    Object? lastError;
    for (final m in models) {
      try {
        // Minta pikiran singkat; bila parameternya ditolak (HTTP 400), ulangi tanpa itu.
        var res = await _post(prompt, m.name, m.timeout, lowThinking: true);
        if (res.statusCode == 400) {
          res = await _post(prompt, m.name, m.timeout, lowThinking: false);
        }
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (res.statusCode != 200) {
          throw StateError(geminiErrorMessage(body, res.statusCode));
        }
        final ai = parseAi(extractModelText(body), sent.length);
        return CafeAi(
          summary: ai.summary,
          notes: [...ai.notes, ...List.filled(places.length - sent.length, '')],
        );
      } catch (e) {
        lastError = '${m.name}: ${e is StateError ? e.message : e}';
      }
    }
    throw StateError('$lastError');
  }

  Future<http.Response> _post(
    String prompt,
    String model,
    Duration timeout, {
    required bool lowThinking,
  }) {
    return _client
        .post(
          Uri.https(
            'generativelanguage.googleapis.com',
            '/v1beta/models/$model:generateContent',
          ),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': Env.geminiApiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.2,
              'responseMimeType': 'application/json',
              if (lowThinking) 'thinkingConfig': {'thinkingLevel': 'low'},
            },
          }),
        )
        .timeout(timeout);
  }
}

String geminiErrorMessage(dynamic body, int status) {
  final msg = body is Map && body['error'] is Map
      ? (body['error'] as Map)['message']
      : null;
  return 'HTTP $status: ${msg ?? 'tidak ada pesan'}';
}

/// Menggabungkan bagian teks jawaban pertama; bagian "thought" dan tanda tangan
/// pikiran diabaikan.
String extractModelText(dynamic body) {
  final candidates = body is Map ? body['candidates'] : null;
  if (candidates is! List || candidates.isEmpty) {
    final reason = body is Map && body['promptFeedback'] is Map
        ? (body['promptFeedback'] as Map)['blockReason']
        : null;
    throw StateError('AI tidak mengembalikan jawaban${reason == null ? '' : ' ($reason)'}.');
  }
  final content = (candidates.first as Map)['content'];
  final parts = content is Map ? content['parts'] : null;
  if (parts is! List) throw StateError('AI tidak mengembalikan jawaban.');
  final text = parts
      .whereType<Map>()
      .where((p) => p['thought'] != true && p['text'] is String)
      .map((p) => p['text'] as String)
      .join();
  if (text.trim().isEmpty) throw StateError('AI tidak mengembalikan jawaban.');
  return text;
}

class CafeAi {
  const CafeAi({required this.summary, required this.notes});

  final String summary;
  final List<String> notes;
}

/// Membaca {"summary": "...", "notes": [{"i":0,"note":"..."}]} (atau array catatan
/// saja) menjadi [CafeAi] dengan [count] catatan.
CafeAi parseAi(String text, int count) {
  final decoded = jsonDecode(text.replaceAll(RegExp(r'```(?:json)?'), '').trim());
  final raw = decoded is List ? decoded : (decoded is Map ? decoded['notes'] : null);
  if (raw is! List) throw const FormatException('Format jawaban AI tidak sesuai.');
  final out = List<String>.filled(count, '');
  for (final e in raw) {
    if (e is Map && e['i'] is int && e['note'] != null) {
      final i = e['i'] as int;
      if (i >= 0 && i < count) out[i] = e['note'].toString().trim();
    }
  }
  final summary = decoded is Map ? (decoded['summary'] ?? '').toString().trim() : '';
  return CafeAi(summary: summary, notes: out);
}