import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/game_config.dart';
import '../theme.dart';

/// Что даёт аккаунт — показываем везде, где без него чего-то не хватает.
final signUpPerks = <(IconData, String)>[
  (
    LucideIcons.coins,
    '+${GameConfig.welcomeCoins} монет сразу после регистрации',
  ),
  (
    LucideIcons.cloudCheck,
    'Прогресс на сервере: не пропадёт при смене телефона',
  ),
  (LucideIcons.swords, 'Дуэли с друзьями, а не только с ботами'),
  (
    LucideIcons.users,
    'Тренировка вместе: +${(GameConfig.jointBonus * 100).round()}% опыта',
  ),
  (LucideIcons.trophy, 'Лига с живыми игроками и рейтинг друзей'),
  (LucideIcons.bell, 'Уведомления: заявки, нападения, серия под угрозой'),
];

/// Заметное приглашение создать аккаунт.
class SignUpCard extends StatelessWidget {
  const SignUpCard({super.key, this.compact = false});

  /// Компактный вид — заголовок, две выгоды и кнопка.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final perks = compact ? signUpPerks.take(2) : signUpPerks;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.gift, size: 20, color: accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Создай аккаунт',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (icon, text) in perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: () => context.go('/profile/account'),
            child: const Text('Создать за минуту'),
          ),
        ],
      ),
    );
  }
}
