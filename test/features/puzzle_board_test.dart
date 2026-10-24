import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pilot/features/challenges/puzzle_board.dart';

int _inversions(PuzzleBoard b) {
  final t = [for (var i = 0; i < PuzzleBoard.cells; i++) b.tileAt(i)]
      .where((v) => v != 0)
      .toList();
  var n = 0;
  for (var i = 0; i < t.length; i++) {
    for (var j = i + 1; j < t.length; j++) {
      if (t[i] > t[j]) n++;
    }
  }
  return n;
}

void main() {
  test('papan awal sudah tersusun', () {
    final b = PuzzleBoard.solved();
    expect(b.isSolved, isTrue);
    expect(b.emptyIndex, PuzzleBoard.cells - 1);
    expect(b.correctCount, PuzzleBoard.cells - 1);
    expect(b.moveCount, 0);
  });

  test('hasil acak tidak langsung selesai dan selalu bisa diselesaikan', () {
    for (var seed = 0; seed < 200; seed++) {
      final b = PuzzleBoard.shuffled(random: Random(seed));
      expect(b.isSolved, isFalse);
      expect(_inversions(b).isEven, isTrue);
      expect(b.moveCount, 0);
    }
  });

  test('acak satu langkah bisa dikembalikan dengan satu geseran', () {
    final b = PuzzleBoard.shuffled(moves: 1, random: Random(1));
    expect(b.isSolved, isFalse);
    expect(b.move(PuzzleBoard.cells - 1), isTrue);
    expect(b.isSolved, isTrue);
    expect(b.moveCount, 1);
  });

  test('hanya petak bersebelahan dengan ruang kosong yang bisa digeser', () {
    final b = PuzzleBoard.solved();
    expect(b.canMove(7), isTrue);
    expect(b.canMove(5), isTrue);
    expect(b.canMove(0), isFalse);
    expect(b.canMove(8), isFalse);
    expect(b.canMove(-1), isFalse);
    expect(b.canMove(PuzzleBoard.cells), isFalse);
    expect(b.move(0), isFalse);
    expect(b.moveCount, 0);
    expect(b.move(7), isTrue);
    expect(b.emptyIndex, 7);
    expect(b.moveCount, 1);
  });

  test('petak di ujung baris sebelumnya tidak dianggap bersebelahan', () {
    final tiles = List<int>.generate(9, (i) => i == 8 ? 0 : i + 1);
    tiles[8] = tiles[6];
    tiles[6] = 0;
    final b = PuzzleBoard.fromTiles(tiles);
    expect(b.emptyIndex, 6);
    expect(b.canMove(5), isFalse);
    expect(b.canMove(7), isTrue);
    expect(b.canMove(3), isTrue);
  });

  test('fromTiles menolak data tidak valid', () {
    expect(() => PuzzleBoard.fromTiles([1, 2, 3]), throwsArgumentError);
    expect(
      () => PuzzleBoard.fromTiles(List<int>.filled(PuzzleBoard.cells, 1)),
      throwsArgumentError,
    );
  });
}
