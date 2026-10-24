import 'dart:math';

class PuzzleBoard {
  PuzzleBoard._(List<int> tiles)
    : _tiles = List<int>.of(tiles),
      _empty = tiles.indexOf(0);

  static const size = 3;
  static const cells = size * size;
  static const scrambleMoves = 30;

  factory PuzzleBoard.solved() => PuzzleBoard._(
    List<int>.generate(cells, (i) => i == cells - 1 ? 0 : i + 1),
  );

  factory PuzzleBoard.fromTiles(List<int> tiles) {
    final sorted = [...tiles]..sort();
    final valid =
        tiles.length == cells &&
        List<int>.generate(cells, (i) => i).every((i) => sorted[i] == i);
    if (!valid) {
      throw ArgumentError(
        'Papan harus berisi angka 0 sampai ${cells - 1} tepat sekali.',
      );
    }
    return PuzzleBoard._(tiles);
  }

  factory PuzzleBoard.shuffled({int moves = scrambleMoves, Random? random}) {
    final rnd = random ?? Random();
    final board = PuzzleBoard.solved();
    var previous = -1;
    for (var i = 0; i < moves; i++) {
      previous = board._randomStep(rnd, previous);
    }
    while (board.isSolved) {
      previous = board._randomStep(rnd, previous);
    }
    return board;
  }

  final List<int> _tiles;
  int _empty;
  int _moves = 0;

  int get emptyIndex => _empty;
  int get moveCount => _moves;

  int tileAt(int index) => _tiles[index];
  int indexOfTile(int tile) => _tiles.indexOf(tile);

  bool get isSolved {
    for (var i = 0; i < cells - 1; i++) {
      if (_tiles[i] != i + 1) return false;
    }
    return _tiles[cells - 1] == 0;
  }

  int get correctCount {
    var n = 0;
    for (var i = 0; i < cells - 1; i++) {
      if (_tiles[i] == i + 1) n++;
    }
    return n;
  }

  bool canMove(int index) =>
      index >= 0 && index < cells && _neighbors().contains(index);

  bool move(int index) {
    if (!canMove(index)) return false;
    _swapWithEmpty(index);
    _moves++;
    return true;
  }

  List<int> _neighbors() {
    final row = _empty ~/ size;
    final col = _empty % size;
    return [
      if (row > 0) _empty - size,
      if (row < size - 1) _empty + size,
      if (col > 0) _empty - 1,
      if (col < size - 1) _empty + 1,
    ];
  }

  void _swapWithEmpty(int index) {
    _tiles[_empty] = _tiles[index];
    _tiles[index] = 0;
    _empty = index;
  }

  int _randomStep(Random rnd, int previous) {
    final options = _neighbors().where((n) => n != previous).toList();
    final pick = options[rnd.nextInt(options.length)];
    final old = _empty;
    _swapWithEmpty(pick);
    return old;
  }
}
