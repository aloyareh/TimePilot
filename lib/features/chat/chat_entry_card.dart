import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'chat_page.dart';

/// Pintu masuk chatbot AI di Beranda (PBI-24). Lebar sama dengan
/// CafeEntryCard, tinggi sekitar setengahnya.
class ChatEntryCard extends StatelessWidget {
  const ChatEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.r24);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: radius,
            boxShadow: AppShadows.soft,
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ChatPage()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.navy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      'Tanya Asisten AI',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.navy),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}