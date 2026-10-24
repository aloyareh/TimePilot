import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/theme/app_theme.dart';
import 'shake_counter.dart';

class ShakeChallengePage extends StatefulWidget {
  const ShakeChallengePage({super.key, this.difficulty = 1});

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
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: ValueListenableBuilder<int>(
            valueListenable: _count,
            builder: (context, count, _) {
              final done = count >= target;
              final accent = done ? AppColors.success : AppColors.orange;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 144,
                    height: 144,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.medium,
                    ),
                    child: Icon(
                      done ? Icons.check_circle : Icons.vibration,
                      size: 80,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  Text(
                    done ? 'Alarm dimatikan!' : 'Kocok HP-mu!',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Kocok $target kali untuk mematikan alarm.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.r24),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$count / $target',
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                          child: LinearProgressIndicator(
                            value: count / target,
                            minHeight: 12,
                            color: done ? AppColors.success : AppColors.blue,
                            backgroundColor: AppColors.surfaceGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_sensorError != null) ...[
                    const SizedBox(height: AppSpacing.s24),
                    Text(
                      _sensorError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
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
