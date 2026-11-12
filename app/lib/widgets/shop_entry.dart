import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/game_config.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'motion.dart';

/// Золото премиума — общий цвет для магазина, короны и баннеров.
const premiumGold = Color(0xFFD9B25A);

/// Заметная кнопка магазина для шапки главного экрана.
class ShopButton extends StatelessWidget {
  const ShopButton({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: 'Магазин',
      child: Pressable(
        child: Semantics(
          button: true,
          label: 'Магазин',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.go('/shop'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shoppingBag, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'Магазин',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Баннер премиума: без подписки — приглашение, с ней — статус.
class PremiumBanner extends ConsumerWidget {
  const PremiumBanner({super.key, this.compact = false});

  /// Узкая полоса (в магазине) вместо карточки (в профиле).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(heroProvider)?.premium;
    final active = premium?.active ?? false;
    final bonus = (GameConfig.premiumCoinBonus * 100).round();
    final title = active
        ? (premium!.isTester ? 'Премиум бета-тестера' : 'Премиум активен')
        : 'IronRise Премиум';
    final subtitle = active
        ? 'Золотые вещи доступны в магазине'
        : '+$bonus% монет, золотые вещи, корона у ника';
    return Pressable(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/shop/premium'),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 8 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                premiumGold.withValues(alpha: 0.30),
                premiumGold.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: premiumGold.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.crown,
                color: premiumGold,
                size: compact ? 18 : 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!compact || !active)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
