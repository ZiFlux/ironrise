import 'package:flutter/material.dart';

import '../legal/privacy_policy.dart';
import '../theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Конфиденциальность')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('Политика конфиденциальности', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Обновлено $privacyPolicyUpdated', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          for (final section in privacyPolicy) ...[
            const SizedBox(height: 24),
            Text(section.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(section.body, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
