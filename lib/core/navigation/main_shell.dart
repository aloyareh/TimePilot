import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/feedback/feedback_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/tasks/task_list_page.dart';
import '../theme/app_theme.dart';

/// Kerangka utama aplikasi (PBI-05): Bottom Navigation 4 menu.
/// Home | Kesan Pesan | Profile | Logout
///
/// Logout bukan halaman: menekannya menampilkan dialog konfirmasi,
/// tab yang sedang aktif tidak berubah.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _logoutIndex = 3;

  int _index = 0;

  // Urutan harus sama dengan 3 tab pertama NavigationBar.
  static const _pages = <Widget>[
    TaskListPage(), // Home (dashboard)
    FeedbackPage(), // Kesan Pesan
    ProfilePage(), // Profile
  ];

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Sesi di perangkat ini akan dihapus dan kamu kembali ke layar login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(96, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // AuthGate otomatis menampilkan LoginPage setelah state jadi null.
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  void _onSelected(int i) {
    if (i == _logoutIndex) {
      _confirmLogout();
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack menjaga state tiap tab (scroll, form) saat berpindah.
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
            tooltip: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review_rounded),
            label: 'Kesan Pesan',
            tooltip: 'Kesan Pesan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
            tooltip: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.logout_rounded),
            label: 'Logout',
            tooltip: 'Keluar dari akun',
          ),
        ],
      ),
    );
  }
}
