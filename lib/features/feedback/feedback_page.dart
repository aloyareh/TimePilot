import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// PLACEHOLDER tab "Kesan Pesan".
/// Diganti dengan form CRUD + daftar pesan di PBI-26 (Sprint 3).
class FeedbackPage extends StatelessWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kesan Pesan')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rate_review_outlined, size: 56, color: AppColors.blue),
              SizedBox(height: 12),
              Text(
                'Kesan & Pesan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text('Fitur ini segera hadir.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
