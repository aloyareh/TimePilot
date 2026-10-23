import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/theme/app_theme.dart';
import 'balance_tracker.dart';

class BalanceChallengePage extends StatefulWidget {
  const BalanceChallengePage({super.key, this.difficulty = 1});

  final int difficulty;

  @override
  State<BalanceChallengePage> createState() => _BalanceChallengePageState();
}

class _BalanceChallengePageState extends State<BalanceChallengePage> {
  static const _maxAngle = 20 * pi / 180;
  static const _uiIntervalMs = 33;

  final _tracker = BalanceTracker();
  final _view = ValueNotifier<_BalanceView>(const _BalanceView.initial());
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  int _lastUiMs = 0;
  bool _finished = false;
  String? _sensorError;

  @override
  void initState() {
    super.initState();
    _accSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((e) => _tracker.updateAccel(e.x, e.y, e.z), onError: _onError);
    _gyroSub = gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
        .listen(_onGyro, onError: _onError);
  }

  void _onError(Object e) {
    debugPrint('Balance sensor error: $e');
    if (mounted) {
      setState(
        () => _sensorError =
            'Sensor gyroscope/accelerometer tidak tersedia di perangkat ini.',
      );
    }
  }

  void _onGyro(GyroscopeEvent e) {
    if (_finished) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final roundDone = _tracker.updateGyro(e.x, e.y, now);
    if (roundDone) HapticFeedback.mediumImpact();
    if (roundDone || now - _lastUiMs >= _uiIntervalMs) {
      _lastUiMs = now;
      _publish();
    }
    if (_tracker.isDone) _complete();
  }

  void _publish() {
    _view.value = _BalanceView(
      x: (_tracker.roll / _maxAngle).clamp(-1.0, 1.0),
      y: (_tracker.pitch / _maxAngle).clamp(-1.0, 1.0),
      balanced: _tracker.isBalanced,
      heldMs: _tracker.heldMs,
      rounds: _tracker.completedRounds,
    );
  }

  Future<void> _complete() async {
    if (_finished) return;
    _finished = true;
    await _accSub?.cancel();
    await _gyroSub?.cancel();
    _accSub = _gyroSub = null;
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _accSub?.cancel();
    _gyroSub?.cancel();
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final holdSeconds = _tracker.holdMs / 1000;

    return Scaffold(
      appBar: AppBar(title: const Text('Balance Challenge')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: ValueListenableBuilder<_BalanceView>(
            valueListenable: _view,
            builder: (context, v, _) {
              final done = v.rounds >= _tracker.rounds;
              final heldSec = v.heldMs / 1000;
              final round = done ? _tracker.rounds : v.rounds + 1;
              final accent = done || v.balanced
                  ? AppColors.success
                  : AppColors.orange;
              return Column(
                children: [
                  Text(
                    done ? 'Alarm dimatikan!' : 'Seimbangkan HP-mu!',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Jaga bola di lingkaran target selama '
                    '${holdSeconds.toStringAsFixed(0)} detik, '
                    '${_tracker.rounds} kali.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.medium,
                          ),
                          child: CustomPaint(
                            painter: _BalancePainter(
                              x: v.x,
                              y: v.y,
                              balanced: v.balanced,
                              targetFraction: _tracker.tolerance / _maxAngle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.r24),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Ronde $round / ${_tracker.rounds}',
                              style: theme.textTheme.titleMedium,
                            ),
                            const Spacer(),
                            Text(
                              done
                                  ? 'Selesai'
                                  : '${heldSec.toStringAsFixed(1)} / '
                                        '${holdSeconds.toStringAsFixed(0)} dtk',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                          child: LinearProgressIndicator(
                            value: done
                                ? 1
                                : (heldSec / holdSeconds).clamp(0.0, 1.0),
                            minHeight: 12,
                            color: accent,
                            backgroundColor: AppColors.surfaceGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_sensorError != null) ...[
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      _sensorError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (kDebugMode && !done) ...[
                    const SizedBox(height: AppSpacing.s4),
                    TextButton(
                      onPressed: () {
                        _tracker.debugCompleteRound();
                        _publish();
                        if (_tracker.isDone) _complete();
                      },
                      child: const Text('Simulasi 1 ronde (debug)'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BalanceView {
  const _BalanceView({
    required this.x,
    required this.y,
    required this.balanced,
    required this.heldMs,
    required this.rounds,
  });

  const _BalanceView.initial()
    : x = 0,
      y = 0,
      balanced = true,
      heldMs = 0,
      rounds = 0;

  final double x;
  final double y;
  final bool balanced;
  final int heldMs;
  final int rounds;
}

class _BalancePainter extends CustomPainter {
  _BalancePainter({
    required this.x,
    required this.y,
    required this.balanced,
    required this.targetFraction,
  });

  final double x;
  final double y;
  final bool balanced;
  final double targetFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ballRadius = radius * 0.1;
    final travel = radius - ballRadius;

    canvas.drawCircle(center, radius, Paint()..color = AppColors.surfaceGray);
    final targetColor = balanced ? AppColors.success : AppColors.orange;
    final targetR = radius * targetFraction;
    canvas.drawCircle(
      center,
      targetR,
      Paint()..color = targetColor.withAlpha(64),
    );
    canvas.drawCircle(
      center,
      targetR,
      Paint()
        ..color = targetColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    var offset = Offset(x, y) * travel;
    if (offset.distance > travel) {
      offset = offset / offset.distance * travel;
    }
    canvas.drawCircle(
      center + offset,
      ballRadius,
      Paint()..color = balanced ? AppColors.success : AppColors.navy,
    );
  }

  @override
  bool shouldRepaint(_BalancePainter old) =>
      old.x != x ||
      old.y != y ||
      old.balanced != balanced ||
      old.targetFraction != targetFraction;
}
