import '../l10n/tr.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/game_config.dart';
import '../theme.dart';

/// Что даёт аккаунт — показываем везде, где без него чего-то не хватает.
final signUpPerks = <(IconData, String)>[
  (
    LucideIcons.coins,
    tr('+{welcomeCoins} монет за регистрацию', {
      'welcomeCoins': GameConfig.welcomeCoins,
    }),
  ),
  (LucideIcons.cloudCheck, tr('Прогресс не пропадёт при смене телефона')),
  (LucideIcons.swords, tr('Дуэли с друзьями, а не только с ботами')),
  (
    LucideIcons.users,
    tr('Тренировка вместе: +{p1}% опыта', {
      'p1': (GameConfig.jointBonus * 100).round(),
    }),
  ),
  (LucideIcons.trophy, tr('Лига с живыми игроками и рейтинг друзей')),
  (LucideIcons.bell, tr('Уведомления: заявки, нападения, серия под угрозой')),
];

/// Выгоды аккаунта плитками по две в ряд: иконка цветом стиля и короткий текст.
class SignUpPerksGrid extends StatelessWidget {
  const SignUpPerksGrid({super.key, required this.perks});

  final List<(IconData, String)> perks;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    Widget tile((IconData, String) p) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(p.$1, size: 18, color: accent),
          const SizedBox(height: 8),
          Text(p.$2, style: const TextStyle(fontSize: 13, height: 1.3)),
        ],
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < perks.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(perks[i])),
                const SizedBox(width: 8),
                Expanded(
                  child: i + 1 < perks.length
                      ? tile(perks[i + 1])
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Заметное приглашение создать аккаунт: заголовок, выгоды плитками,
/// «Создать» и «У меня уже есть аккаунт».
class SignUpCard extends StatelessWidget {
  const SignUpCard({super.key, this.compact = false});

  /// Компактный вид — заголовок, две выгоды и кнопка.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final perks = (compact ? signUpPerks.take(2) : signUpPerks.take(4))
        .toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Сохрани героя'),
              style: TextStyle(fontFamily: displayFont, fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Сейчас прогресс только на этом телефоне'),
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            SignUpPerksGrid(perks: perks),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push('/profile/account'),
              child: Text(tr('Создать аккаунт')),
            ),
            if (!compact)
              TextButton(
                onPressed: () => context.push('/profile/account?login=1'),
                child: Text(tr('У меня уже есть аккаунт')),
              ),
          ],
        ),
      ),
    );
  }
}
