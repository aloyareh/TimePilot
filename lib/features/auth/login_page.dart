import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

final _usernameRe = RegExp(r'^[a-z0-9_.]{3,30}$');

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();

  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  bool _bioEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBiometricFlag();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricFlag() async {
    final enabled = await ref.read(authRepositoryProvider).isBiometricEnabled();
    if (!mounted) return;
    setState(() => _bioEnabled = enabled);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ctrl = ref.read(authControllerProvider.notifier);
    final username = _username.text.trim();
    final name = _fullName.text.trim();
    final err = _register
        ? await ctrl.register(
            username,
            _password.text,
            name.isEmpty ? null : name,
          )
        : await ctrl.login(username, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  Future<void> _biometric() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref
        .read(authControllerProvider.notifier)
        .loginWithBiometric();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  void _toggleMode() {
    setState(() {
      _register = !_register;
      _error = null;
      _formKey.currentState?.reset();
    });
  }

  Widget _logo(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.navy, AppColors.blue],
            ),
            borderRadius: BorderRadius.circular(AppRadius.r24),
            boxShadow: AppShadows.medium,
          ),
          child: const Icon(
            Icons.navigation_rounded,
            size: 40,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Text.rich(
          TextSpan(
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            children: const [
              TextSpan(
                text: 'Time',
                style: TextStyle(color: AppColors.navy),
              ),
              TextSpan(
                text: 'Pilot',
                style: TextStyle(color: AppColors.orange),
              ),
            ],
          ),
        ),
        Text(
          'Navigate Your Time.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.navInactive,
          ),
        ),
      ],
    );
  }

  Widget _errorBox(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _logo(theme),
                  const SizedBox(height: AppSpacing.s32),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.r24),
                      boxShadow: AppShadows.medium,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _register ? 'Buat Akun' : 'Selamat Datang Kembali',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            _register
                                ? 'Mulai perjalananmu bersama TimePilot'
                                : 'Masuk untuk melanjutkan perjalananmu',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.s24),
                          if (_register) ...[
                            TextFormField(
                              controller: _fullName,
                              enabled: !_busy,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nama lengkap (opsional)',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s12),
                          ],
                          TextFormField(
                            controller: _username,
                            enabled: !_busy,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) {
                              final value = (v ?? '').trim().toLowerCase();
                              if (value.isEmpty) return 'Username wajib diisi.';
                              if (_register && !_usernameRe.hasMatch(value)) {
                                return '3\u{2013}30 karakter: huruf, angka, titik, garis bawah.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _busy ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (value.isEmpty) return 'Password wajib diisi.';
                              if (_register &&
                                  (value.length < 8 || value.length > 72)) {
                                return 'Password harus 8\u{2013}72 karakter.';
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpacing.s16),
                            _errorBox(scheme),
                          ],
                          const SizedBox(height: AppSpacing.s24),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_register ? 'Daftar' : 'Masuk'),
                          ),
                          if (!_register && _bioEnabled) ...[
                            const SizedBox(height: AppSpacing.s12),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _biometric,
                              icon: const Icon(Icons.fingerprint),
                              label: const Text('Masuk dengan biometrik'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _register ? 'Sudah punya akun?' : 'Belum punya akun?',
                        style: theme.textTheme.bodySmall,
                      ),
                      TextButton(
                        onPressed: _busy ? null : _toggleMode,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s8,
                          ),
                        ),
                        child: Text(_register ? 'Masuk' : 'Daftar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
