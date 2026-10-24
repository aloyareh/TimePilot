import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'math_quiz.dart';

class MathChallengePage extends StatefulWidget {
  const MathChallengePage({super.key, this.difficulty = 1});

  final int difficulty;

  @override
  State<MathChallengePage> createState() => _MathChallengePageState();
}

class _MathChallengePageState extends State<MathChallengePage> {
  final MathQuiz _quiz = MathQuiz();
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _finished = false;
  String? _wrongMessage;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_finished) return;
    final value = int.tryParse(_controller.text.trim());
    if (value == null) return;

    final wrongAnswer = _quiz.current.answer;
    final wrongText = _quiz.current.text;
    final result = _quiz.submit(value);
    _controller.clear();

    switch (result) {
      case MathAnswerResult.correct:
        HapticFeedback.lightImpact();
        setState(() => _wrongMessage = null);
        _focus.requestFocus();
      case MathAnswerResult.wrong:
        HapticFeedback.heavyImpact();
        setState(
          () => _wrongMessage =
              'Salah! $wrongText = $wrongAnswer. Ulang dari soal 1.',
        );
        _focus.requestFocus();
      case MathAnswerResult.completed:
        HapticFeedback.heavyImpact();
        setState(() {
          _finished = true;
          _wrongMessage = null;
        });
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _quiz.total;
    final streak = _finished ? total : _quiz.streak;

    return Scaffold(
      appBar: AppBar(title: const Text('Soal Matematika')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            children: [
              Text(
                _finished ? 'Alarm dimatikan!' : 'Jawab $total soal beruntun',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Salah satu saja, ulang dari soal 1.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.s24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: streak > 0
                        ? AppColors.orange
                        : AppColors.navInactive,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    'Streak $streak / $total',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: Container(
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                          color: i < streak
                              ? (_finished ? AppColors.success : AppColors.blue)
                              : AppColors.surfaceGray,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.r24),
                  boxShadow: AppShadows.medium,
                ),
                child: Column(
                  children: [
                    Text(
                      _finished
                          ? 'Selesai!'
                          : 'Soal ${_quiz.number} dari $total',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      _finished ? '✓' : '${_quiz.current.text} = ?',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _finished ? AppColors.success : AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              if (_wrongMessage != null) ...[
                const SizedBox(height: AppSpacing.s16),
                Text(
                  _wrongMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s24),
              TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: !_finished,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                style: theme.textTheme.headlineMedium,
                decoration: const InputDecoration(hintText: 'Jawabanmu'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.s16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _finished ? null : _submit,
                  child: const Text('Jawab'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
