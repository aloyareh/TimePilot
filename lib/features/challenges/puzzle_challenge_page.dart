import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'puzzle_board.dart';

const _puzzleAsset = 'assets/images/puzzle.jpg';
const _tileGap = 1.5;

class PuzzleChallengePage extends StatefulWidget {
  const PuzzleChallengePage({super.key, this.difficulty = 1});

  final int difficulty;

  @override
  State<PuzzleChallengePage> createState() => _PuzzleChallengePageState();
}

class _PuzzleChallengePageState extends State<PuzzleChallengePage> {
  PuzzleBoard _board = PuzzleBoard.shuffled();
  bool _finished = false;

  void _onTap(int index) {
    if (_finished) return;
    if (!_board.move(index)) return;
    HapticFeedback.selectionClick();
    if (_board.isSolved) {
      _complete();
    } else {
      setState(() {});
    }
  }

  Future<void> _complete() async {
    setState(() => _finished = true);
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Widget _boardView(BuildContext context, double side) {
    const n = PuzzleBoard.size;
    final cell = side / n;
    final cacheWidth = (side * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox(
      width: side,
      height: side,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(AppRadius.r16),
          boxShadow: AppShadows.medium,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.r16),
          child: Stack(
            children: [
              for (var tile = 1; tile < PuzzleBoard.cells; tile++)
                AnimatedPositioned(
                  key: ValueKey(tile),
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  left: (_board.indexOfTile(tile) % n) * cell,
                  top: (_board.indexOfTile(tile) ~/ n) * cell,
                  width: cell,
                  height: cell,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onTap(_board.indexOfTile(tile)),
                    child: _PuzzleTile(
                      tile: tile,
                      boardSide: side,
                      cell: cell,
                      cacheWidth: cacheWidth,
                    ),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _finished ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: _PuzzleImage(cacheWidth: cacheWidth),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const total = PuzzleBoard.cells - 1;
    final correct = _finished ? total : _board.correctCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle Gambar')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            children: [
              Text(
                _finished ? 'Alarm dimatikan!' : 'Susun gambarnya!',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Geser petak ke ruang kosong sampai gambar utuh.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.s12),
              _StatsCard(
                correct: correct,
                total: total,
                moves: _board.moveCount,
                done: _finished,
              ),
              const SizedBox(height: AppSpacing.s12),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, c) =>
                        _boardView(context, min(c.maxWidth, c.maxHeight)),
                  ),
                ),
              ),
              if (kDebugMode && !_finished)
                TextButton(
                  onPressed: () {
                    _board = PuzzleBoard.solved();
                    _complete();
                  },
                  child: const Text('Selesaikan puzzle (debug)'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PuzzleImage extends StatelessWidget {
  const _PuzzleImage({required this.cacheWidth});

  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _puzzleAsset,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) =>
          ColoredBox(color: AppColors.blue.withValues(alpha: 0.2)),
    );
  }
}

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({
    required this.tile,
    required this.boardSide,
    required this.cell,
    required this.cacheWidth,
  });

  final int tile;
  final double boardSide;
  final double cell;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final origin = tile - 1;
    final row = origin ~/ PuzzleBoard.size;
    final col = origin % PuzzleBoard.size;
    return Padding(
      padding: const EdgeInsets.all(_tileGap),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: Stack(
          children: [
            Positioned(
              left: -(col * cell + _tileGap),
              top: -(row * cell + _tileGap),
              width: boardSide,
              height: boardSide,
              child: _PuzzleImage(cacheWidth: cacheWidth),
            ),
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Text(
                  '$tile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.correct,
    required this.total,
    required this.moves,
    required this.done,
  });

  final int correct;
  final int total;
  final int moves;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.r24),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r12),
            child: const SizedBox(
              width: 56,
              height: 56,
              child: _PuzzleImage(cacheWidth: 168),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Petak benar $correct / $total',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text('Langkah $moves', style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  child: LinearProgressIndicator(
                    value: correct / total,
                    minHeight: 10,
                    color: done ? AppColors.success : AppColors.blue,
                    backgroundColor: AppColors.surfaceGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
