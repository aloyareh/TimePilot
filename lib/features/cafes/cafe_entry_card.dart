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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, AppColors.blue],
          ),
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                  ),
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
                      Text(
                        'REKOMENDASI KERJA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          letterSpacing: 0.8,
                        ),
                      ),
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
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
