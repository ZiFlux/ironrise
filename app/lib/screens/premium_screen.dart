import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/game_config.dart';
import '../state/providers.dart';
import '../theme.dart';

const _gold = Color(0xFFD9B25A);
const _beta = Color(0xFF8B5CF6);

/// Премиум-подписка: что даёт и статус. Оплаты пока нет — премиум есть у бета-тестеров.
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  static final perks = <(IconData, String, String)>[
    (
      LucideIcons.coins,
      '+${(GameConfig.premiumCoinBonus * 100).round()}% монет',
      'За каждую тренировку. Опыт тот же — силу не купить',
    ),
    (
      LucideIcons.gem,
      'Премиум-вещи',
      'Новые эксклюзивы в магазине. Золотой комплект теперь бесплатно у всех',
    ),
    (LucideIcons.crown, 'Корона у ника', 'В профиле видно, что ты с нами'),
    (
      LucideIcons.heartHandshake,
      'Поддержка IronRise',
      'Подписка оплачивает сервер и новые функции',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(heroProvider)?.premium;
    final active = premium?.active ?? false;
    final tester = premium?.isTester ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Премиум')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _gold.withValues(alpha: 0.28),
                  _gold.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: _gold.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.crown, color: _gold, size: 32),
                const SizedBox(height: 12),
                Text(
                  active ? 'Премиум активен' : 'IronRise Премиум',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tester
                      ? 'Навсегда — спасибо, что тестируете IronRise'
                      : active && premium?.until != null
                      ? 'До ${_date(premium!.until!)}'
                      : 'Косметика и монеты. На силу героя не влияет',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final (icon, title, text) in perks) _Perk(icon, title, text),
          if (tester) ...[
            const SizedBox(height: 8),
            const Text(
              'Привилегии бета-тестера',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const _Perk(
              LucideIcons.watch,
              'Без штрафа за часы',
              'Тренировки без часов дают полный опыт, а не ×0,5',
              color: _beta,
            ),
            const _Perk(
              LucideIcons.flaskConical,
              'Вещи тестера — навсегда',
              'Кепка, верх и кроссовки «Бета» закреплены за аккаунтом',
              color: _beta,
            ),
          ],
          const SizedBox(height: 20),
          if (active)
            OutlinedButton(
              onPressed: () => context.go('/shop'),
              child: const Text('В магазин'),
            )
          else ...[
            const FilledButton(
              onPressed: null,
              child: Text('Оформить — скоро'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Оплата появится в одном из следующих обновлений',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _Perk extends StatelessWidget {
  const _Perk(this.icon, this.title, this.text, {this.color = _gold});

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
