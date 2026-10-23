import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/features/cafes/cafe_llm_service.dart';

void main() {
  test('extractModelText: mengabaikan thoughtSignature dan bagian thought', () {
    final body = {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'pikiran', 'thought': true},
              {'text': '[{"i":0,"note":"Halo"}]', 'thoughtSignature': 'abc'},
            ],
            'role': 'model',
          },
          'finishReason': 'STOP',
        },
      ],
    };
    expect(extractModelText(body), '[{"i":0,"note":"Halo"}]');
  });

  test('extractModelText: tanpa kandidat melempar StateError', () {
    expect(() => extractModelText({'candidates': []}), throwsStateError);
    expect(
      () => extractModelText({'promptFeedback': {'blockReason': 'SAFETY'}}),
      throwsStateError,
    );
  });

  test('parseAi: ringkasan, urut per indeks, indeks liar dan fence diabaikan', () {
    final r = parseAi(
      '```json\n{"summary":"Coba A.","notes":[{"i":1,"note":"B"},{"i":0,"note":"A"},{"i":9,"note":"X"}]}\n```',
      3,
    );
    expect(r.summary, 'Coba A.');
    expect(r.notes, ['A', 'B', '']);
  });

  test('parseAi: array saja tetap dibaca, tanpa ringkasan; format salah gagal', () {
    final r = parseAi('[{"i":0,"note":"A"}]', 2);
    expect(r.summary, '');
    expect(r.notes, ['A', '']);
    expect(() => parseAi('{"x":1}', 2), throwsFormatException);
  });

  test('geminiErrorMessage memuat status dan pesan', () {
    expect(
      geminiErrorMessage({'error': {'message': 'API key not valid'}}, 400),
      'HTTP 400: API key not valid',
    );
    expect(geminiErrorMessage('x', 500), 'HTTP 500: tidak ada pesan');
  });
}