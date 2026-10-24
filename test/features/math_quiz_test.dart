import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/features/challenges/math_quiz.dart';

void main() {
  test('soal selalu perkalian 1-9 x 1-9, total 5', () {
    final quiz = MathQuiz(random: Random(1));
    expect(quiz.total, 5);
    for (var i = 0; i < 200; i++) {
      final q = MathQuiz(random: Random(i)).current;
      expect(q.a, inInclusiveRange(1, 9));
      expect(q.b, inInclusiveRange(1, 9));
      expect(q.answer, q.a * q.b);
    }
  });

  test('5 jawaban benar beruntun = completed', () {
    final quiz = MathQuiz(random: Random(2));
    for (var i = 0; i < 4; i++) {
      expect(quiz.number, i + 1);
      expect(quiz.submit(quiz.current.answer), MathAnswerResult.correct);
    }
    expect(quiz.streak, 4);
    expect(quiz.submit(quiz.current.answer), MathAnswerResult.completed);
  });

  test('salah di soal manapun => ulang dari nomor 1, streak 0', () {
    final quiz = MathQuiz(random: Random(3));
    quiz.submit(quiz.current.answer);
    quiz.submit(quiz.current.answer);
    quiz.submit(quiz.current.answer);
    expect(quiz.number, 4);

    final wrong = quiz.current.answer + 1;
    expect(quiz.submit(wrong), MathAnswerResult.wrong);
    expect(quiz.number, 1);
    expect(quiz.streak, 0);
    expect(quiz.resets, 1);
  });

  test('salah di soal terakhir juga mengulang dari awal', () {
    final quiz = MathQuiz(random: Random(4));
    for (var i = 0; i < 4; i++) {
      quiz.submit(quiz.current.answer);
    }
    expect(quiz.number, 5);
    expect(quiz.submit(quiz.current.answer + 1), MathAnswerResult.wrong);
    expect(quiz.number, 1);
  });
}
