import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/env.dart';
import '../cafes/cafe_llm_service.dart';

/// Satu pesan dalam percakapan. [fromUser] false = jawaban AI.
class ChatMessage {
  const ChatMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}

/// Maksimum pesan terakhir yang dikirim ke AI agar permintaan tetap ringan.
const chatHistoryLimit = 20;

/// Isi permintaan generateContent untuk percakapan. Fungsi murni.
Map<String, dynamic> buildChatBody(
  List<ChatMessage> history,
  String systemPrompt, {
  bool lowThinking = true,
}) {
  final recent = history.length > chatHistoryLimit
      ? history.sublist(history.length - chatHistoryLimit)
      : history;
  return {
    'systemInstruction': {
      'parts': [
        {'text': systemPrompt},
      ],
    },
    'contents': [
      for (final m in recent)
        {
          'role': m.fromUser ? 'user' : 'model',
          'parts': [
            {'text': m.text},
          ],
        },
    ],
    'generationConfig': {
      'temperature': 0.6,
      if (lowThinking) 'thinkingConfig': {'thinkingLevel': 'low'},
    },
  };
}

/// Instruksi sistem chatbot; [role], [timezone], [currency] dari profil pengguna
/// (boleh kosong).
String buildSystemPrompt({String? role, String? timezone, String? currency}) {
  final who = [
    if (role != null && role.trim().isNotEmpty) 'pekerjaan: ${role.trim()}',
    if (timezone != null && timezone.isNotEmpty) 'zona waktu: $timezone',
    if (currency != null && currency.isNotEmpty) 'mata uang utama: $currency',
  ].join(', ');
  return '''
Kamu adalah asisten di aplikasi Time Pilot, aplikasi pelacak waktu dan tugas untuk freelancer.
Bantu pengguna soal manajemen waktu, menentukan tarif, menagih klien, bekerja lintas zona waktu, dan produktivitas.
${who.isEmpty ? '' : 'Profil pengguna ($who).'}
Jawab dalam Bahasa Indonesia yang ringkas dan praktis.
Tulis teks biasa tanpa format markdown (jangan pakai tanda * atau # ); untuk daftar pakai angka "1." atau tanda "-".
Jika tidak yakin atau tidak tahu, katakan jujur, jangan mengarang fakta.
Untuk pertanyaan hukum, pajak, atau keuangan, beri informasi umum dan sarankan menghubungi ahli.
''';
}

/// Chatbot Gemini lewat REST generateContent (PBI-24). Model dicoba berurutan
/// seperti [CafeLlmService.models].
class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> reply(List<ChatMessage> history, String systemPrompt) async {
    if (Env.geminiApiKey.isEmpty) {
      throw StateError('Fitur chat belum dikonfigurasi (kunci AI kosong).');
    }
    Object? lastError;
    for (final m in CafeLlmService.models) {
      try {
        var res = await _post(history, systemPrompt, m.name, m.timeout, true);
        if (res.statusCode == 400) {
          res = await _post(history, systemPrompt, m.name, m.timeout, false);
        }
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (res.statusCode != 200) {
          throw StateError(geminiErrorMessage(body, res.statusCode));
        }
        return extractModelText(body).trim();
      } catch (e) {
        lastError = '${m.name}: ${e is StateError ? e.message : e}';
      }
    }
    throw StateError('$lastError');
  }

  Future<http.Response> _post(
    List<ChatMessage> history,
    String system,
    String model,
    Duration timeout,
    bool lowThinking,
  ) {
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
          body: jsonEncode(buildChatBody(history, system, lowThinking: lowThinking)),
        )
        .timeout(timeout);
  }
}