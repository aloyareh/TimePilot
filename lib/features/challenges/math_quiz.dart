import 'dart:math';

class MathQuestion {
  const MathQuestion(this.a, this.b);

  final int a;
  final int b;

  int get answer => a * b;
  String get text => '$a × $b';
}

enum MathAnswerResult { correct, wrong, completed }

/// Kuis perkalian 1-9 × 1-9, [total] soal berurutan.
/// Jawaban salah => kembali ke soal 1 dengan soal baru (streak reset).
class MathQuiz {
  MathQuiz({Random? random, this.total = 5}) : _random = random ?? Random() {
    _generate();
  }

  final Random _random;
  final int total;

  late List<MathQuestion> _questions;
  int _index = 0;
  int _resets = 0;

  MathQuestion get current => _questions[_index];

  /// Nomor soal yang sedang dikerjakan (mulai dari 1).
  int get number => _index + 1;

  /// Jumlah jawaban benar beruntun pada percobaan ini.
  int get streak => _index;

  /// Berapa kali pengguna salah dan harus mengulang.
  int get resets => _resets;

  void _generate() {
    _questions = List.generate(
      total,
      (_) => MathQuestion(_random.nextInt(9) + 1, _random.nextInt(9) + 1),
    );
    _index = 0;
  }

  MathAnswerResult submit(int value) {
    if (value != current.answer) {
      _resets++;
      _generate();
      return MathAnswerResult.wrong;
    }
    if (_index == total - 1) {
      _index = total;
      return MathAnswerResult.completed;
    }
    _index++;
    return MathAnswerResult.correct;
  }
}
