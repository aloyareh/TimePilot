import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/theme/app_theme.dart';
import 'shake_counter.dart';

/// Tantangan "Shake to Wake" (PBI-14).
///
/// Target kocokan diacak 10-25 setiap halaman dibuka. Saat target tercapai,
/// halaman memanggil `pop(true)` (kontrak challenge_registry.dart), sehingga
/// alarm dimatikan dan tombol Start Work Session aktif.
///
/// UI tidak membeku: sensor dibaca lewat Stream (event platform channel),
/// per sampel hanya aritmetika ringan, dan UI hanya dibangun ulang saat
/// hitungan berubah (ValueNotifier), bukan setiap sampel.
class ShakeChallengePage extends StatefulWidget {
  const ShakeChallengePage({super.key, this.difficulty = 1});

  /// Diterima dari kontrak registry; target kocokan sengaja acak 10-25
  /// sesuai PBI-14, jadi tidak memengaruhi target.
  final int difficulty;

  @override
  State<ShakeChallengePage> createState() => _ShakeChallengePageState();
}

class _ShakeChallengePageState extends State<ShakeChallengePage> {
  late final ShakeCounter _counter = ShakeCounter(
    target: ShakeCounter.randomTarget(),
  );
  final _count = ValueNotifier<int>(0);
  StreamSubscription<UserAccelerometerEvent>? _sub;
  bool _finished = false;
  String? _sensorError;

  @override
  void initState() {
    super.initState();
    // userAccelerometer = percepatan tanpa gravitasi, jadi HP diam ~0.
    _sub =
        userAccelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          (e) => _onSample(e.x, e.y, e.z),
          onError: (Object _) {
            if (mounted) {
              setState(
                () => _sensorError =
                    'Sensor gerak tidak tersedia di perangkat ini.',
              );
            }
          },
          cancelOnError: false,
        );
  }

  void _onSample(double x, double y, double z) {
    if (_finished) return;
    final counted = _counter.addSample(
      x: x,
      y: y,
      z: z,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!counted) return;
    HapticFeedback.lightImpact();
    _count.value = _counter.count;
    if (_counter.isDone) _complete();
  }

  Future<void> _complete() async {
    _finished = true;
    await _sub?.cancel();
    _sub = null;
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = _counter.target;

    return Scaffold(
      appBar: AppBar(title: const Text('Shake to Wake')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<int>(
            valueListenable: _count,
            builder: (context, count, _) {
              final done = count >= target;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.vibration,
                    size: 96,
                    color: done ? AppColors.success : AppColors.orange,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    done ? 'Alarm dimatikan!' : 'Kocok HP-mu!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kocok $target kali untuk mematikan alarm.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '$count / $target',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: count / target,
                      minHeight: 12,
                      color: done ? AppColors.success : AppColors.blue,
                      backgroundColor: AppColors.surfaceGray,
                    ),
                  ),
                  if (_sensorError != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      _sensorError!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  // Emulator tidak punya sensor: tombol ini hanya ada di debug.
                  if (kDebugMode && !done) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        _counter.addSample(
                          x: 99,
                          y: 0,
                          z: 0,
                          timestampMs:
                              DateTime.now().millisecondsSinceEpoch +
                              1000000 * count,
                        );
                        _count.value = _counter.count;
                        if (_counter.isDone) _complete();
                      },
                      child: const Text('Simulasi 1 kocokan (debug)'),
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
