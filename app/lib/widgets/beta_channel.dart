import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'status_toast.dart';

/// Telegram-канал бета-тестеров: новости, сборки, обратная связь.
final betaChannelUrl = Uri.parse('https://t.me/IronRiseApp');

/// Открывает канал в Telegram (или в браузере, если Telegram не установлен).
Future<void> openBetaChannel(BuildContext context) async {
  final ok = await launchUrl(
    betaChannelUrl,
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok && context.mounted) {
    showStatusError('Не удалось открыть t.me/IronRiseApp');
  }
}

/// Строка «Вступить в канал бета-тестеров» для настроек.
class BetaChannelTile extends StatelessWidget {
  const BetaChannelTile({super.key});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        LucideIcons.send,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('Канал бета-тестеров'),
      subtitle: const Text(
        'Новости, новые сборки и обратная связь — в Telegram',
      ),
      trailing: const Icon(LucideIcons.externalLink, size: 18),
      onTap: () => openBetaChannel(context),
    ),
  );
}
