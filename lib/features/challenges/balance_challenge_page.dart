import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/theme/app_theme.dart';
import 'balance_tracker.dart';

/// Tantangan "Balance Challenge" (PBI-15, US-2).
///
/// Miringkan HP sampai bola masuk ke lingkaran target (posisinya acak tiap ronde),
/// lalu tahan 3 detik berturut-turut, sebanyak 4 ronde. HP yang diam rata di meja
/// tidak lolos karena target selalu miring. Setelah ronde terakhir, halaman
/// memanggil `pop(true)` (kontrak challenge_registry.dart) sehingga alarm
/// dimatikan dan tombol Start Work Session aktif.
///
/// Sensor dibaca lewat Stream; UI hanya di-update ~30 fps lewat ValueNotifier,
/// jadi thread UI tidak terbebani.
class BalanceChallengePage extends StatefulWidget {
  const BalanceChallengePage({super.key, this.difficulty = 1});

  /// Diterima dari kontrak registry; aturan tetap (3 dtk x 4 ronde, target acak).
  final int difficulty;

  @override
  State<BalanceChallengePage> createState() => _BalanceChallengePageState();
}

class _BalanceChallengePageState extends State<BalanceChallengePage> {
  static const _maxAngle = 36 * pi / 180; // simpangan di tepi lingkaran luar
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
      tx: _tracker.targetRoll / _maxAngle,
      ty: _tracker.targetPitch / _maxAngle,
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
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<_BalanceView>(
            valueListenable: _view,
            builder: (context, v, _) {
              final done = v.rounds >= _tracker.rounds;
              final heldSec = v.heldMs / 1000;
              final round = done ? _tracker.rounds : v.rounds + 1;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    done ? 'Alarm dimatikan!' : 'Seimbangkan HP-mu!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Miringkan HP sampai bola masuk lingkaran target, lalu tahan '
                    '${holdSeconds.toStringAsFixed(0)} detik. '
                    'Posisi target berubah tiap ronde (${_tracker.rounds} ronde).',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CustomPaint(
                          painter: _BalancePainter(
                            x: v.x,
                            y: v.y,
                            tx: v.tx,
                            ty: v.ty,
                            balanced: v.balanced,
                            targetFraction: _tracker.tolerance / _maxAngle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 24),
                  Text(
                    'Ronde $round / ${_tracker.rounds}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: done ? 1 : (heldSec / holdSeconds).clamp(0.0, 1.0),
                      minHeight: 12,
                      color: v.balanced ? AppColors.success : AppColors.orange,
                      backgroundColor: AppColors.surfaceGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    done
                        ? 'Selesai'
                        : '${heldSec.toStringAsFixed(1)} / '
                              '${holdSeconds.toStringAsFixed(0)} dtk',
                  ),
                  if (_sensorError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _sensorError!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
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
    required this.tx,
    required this.ty,
    required this.balanced,
    required this.heldMs,
    required this.rounds,
  });

  const _BalanceView.initial()
    : x = 0,
      y = 0,
      tx = 0,
      ty = 0,
      balanced = true,
      heldMs = 0,
      rounds = 0;

  /// Posisi bola ternormalisasi -1..1 (kanan/bawah positif).
  final double x;
  final double y;

  /// Posisi pusat lingkaran target, ternormalisasi seperti [x] dan [y].
  final double tx;
  final double ty;
  final bool balanced;
  final int heldMs;
  final int rounds;
}

class _BalancePainter extends CustomPainter {
  _BalancePainter({
    required this.x,
    required this.y,
    required this.tx,
    required this.ty,
    required this.balanced,
    required this.targetFraction,
  });

  final double x;
  final double y;
  final double tx;
  final double ty;
  final bool balanced;
  final double targetFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ballRadius = radius * 0.1;
    final travel = radius - ballRadius;

    // Lingkaran luar (area gerak bola).
    canvas.drawCircle(center, radius, Paint()..color = AppColors.surfaceGray);
    // Lingkaran target di posisi acak ronde ini.
    final targetColor = balanced ? AppColors.success : AppColors.orange;
    final targetR = radius * targetFraction;
    final targetCenter = center + Offset(tx, ty) * travel;
    canvas.drawCircle(
      targetCenter,
      targetR,
      Paint()..color = targetColor.withAlpha(64),
    );
    canvas.drawCircle(
      targetCenter,
      targetR,
      Paint()
        ..color = targetColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Bola dibatasi di dalam lingkaran luar.
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
      old.tx != tx ||
      old.ty != ty ||
      old.balanced != balanced ||
      old.targetFraction != targetFraction;
}
