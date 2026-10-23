import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'chat_page.dart';

/// Pintu masuk chatbot AI di Beranda (PBI-24).
class ChatEntryCard extends StatelessWidget {
  const ChatEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.chat_bubble_outline, color: AppColors.orange),
          title: const Text(
            'Tanya asisten AI',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Tarif, jadwal, menagih klien, dan lainnya'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ChatPage()),
          ),
        ),
      ),
    );
  }
}