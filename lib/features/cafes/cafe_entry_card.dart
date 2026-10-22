import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'cafe_recommendation_page.dart';

/// Kartu pintu masuk fitur kafe terdekat di dashboard (PBI-25).
class CafeEntryCard extends StatelessWidget {
  const CafeEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(
            Icons.local_cafe_outlined,
            color: AppColors.orange,
          ),
          title: const Text(
            'Cari tempat kerja terdekat',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Kafe & coworking space di sekitarmu (GPS + AI)',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CafeRecommendationPage(),
            ),
          ),
        ),
      ),
    );
  }
}
