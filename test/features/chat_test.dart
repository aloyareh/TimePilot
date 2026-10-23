import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/features/chat/chat_service.dart';

void main() {
  test('buildChatBody: peran user/model berurutan dan instruksi sistem', () {
    final body = buildChatBody(const [
      ChatMessage(text: 'Halo', fromUser: true),
      ChatMessage(text: 'Hai', fromUser: false),
      ChatMessage(text: 'Tarif?', fromUser: true),
    ], 'SISTEM');
    final contents = body['contents'] as List;
    expect(contents.map((c) => (c as Map)['role']), ['user', 'model', 'user']);
    expect(
      ((body['systemInstruction'] as Map)['parts'] as List).first,
      {'text': 'SISTEM'},
    );
    expect((body['generationConfig'] as Map).containsKey('thinkingConfig'), isTrue);
  });

  test('buildChatBody: tanpa lowThinking tidak mengirim thinkingConfig', () {
    final body = buildChatBody(
      const [ChatMessage(text: 'x', fromUser: true)],
      's',
      lowThinking: false,
    );
    expect((body['generationConfig'] as Map).containsKey('thinkingConfig'), isFalse);
  });

  test('buildChatBody: hanya $chatHistoryLimit pesan terakhir dikirim', () {
    final many = [
      for (var i = 0; i < 50; i++)
        ChatMessage(text: 'm$i', fromUser: i.isEven),
    ];
    final contents = buildChatBody(many, 's')['contents'] as List;
    expect(contents, hasLength(chatHistoryLimit));
    expect(
      ((contents.last as Map)['parts'] as List).first,
      {'text': 'm49'},
    );
  });

  test('buildSystemPrompt: memuat profil bila ada, tetap valid bila kosong', () {
    final withProfile = buildSystemPrompt(
      role: 'Web Developer',
      timezone: 'Asia/Jakarta',
      currency: 'IDR',
    );
    expect(withProfile, contains('Web Developer'));
    expect(withProfile, contains('Asia/Jakarta'));
    expect(withProfile, contains('IDR'));
    final empty = buildSystemPrompt();
    expect(empty, isNot(contains('Profil pengguna')));
    expect(empty, contains('Time Pilot'));
  });
}