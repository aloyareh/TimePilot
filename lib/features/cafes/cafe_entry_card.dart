import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'cafe_recommendation_page.dart';

class CafeEntryCard extends StatelessWidget {
  const CafeEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.r24);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: radius,
          boxShadow: AppShadows.medium,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CafeRecommendationPage(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: const Icon(
                    Icons.local_cafe_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Lihat Kafe untuk Co-working Terdekat',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.chevron_right, color: AppColors.navy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}