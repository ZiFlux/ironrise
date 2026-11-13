import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/shop.dart';
import '../state/account_state.dart';
import '../state/providers.dart';
import '../state/season_state.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/item_preview.dart';
import '../widgets/sign_in_gate.dart';

const _gold = Color(0xFFD9B25A);

/// Сезон и батлпас: прогресс по очкам и две дорожки наград по уровням.
class SeasonScreen extends ConsumerWidget {
  const SeasonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(accountProvider).signedIn) {
      return const SignInGate(
        title: 'Сезон',
        icon: LucideIcons.sparkles,
        text:
            'Очки сезона за тренировки, дуэли и советы, награды по 30 уровням: '
            'монеты, бустеры и сезонная одежда. Считает сервер — нужен аккаунт.',
      );
    }
    final season = ref.watch(seasonProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Сезон')),
      body: season.when(
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(seasonProvider.future),
          child: _SeasonView(season: s),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(seasonProvider),
            child: const Text('Не удалось загрузить — повторить'),
          ),
        ),
      ),
    );
  }
}

class _SeasonView extends ConsumerWidget {
  const _SeasonView({required this.season});

  final SeasonInfo season;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    final s = season;
    final maxed = s.level >= s.maxLevel;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сезон ${s.number} · ${s.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Осталось ${s.daysLeft(DateTime.now())} дн. · до ${formatDate(s.endsAt)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '${s.level}',
                      style: figureStyle(size: 32, color: accent),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'уровень из ${s.maxLevel}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxed ? 1 : s.pointsIntoLevel / s.levelPoints,
                    minHeight: 8,
                    color: accent,
                    backgroundColor: AppColors.raised,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  maxed
                      ? 'Все уровни сезона взяты · ${s.points} очков'
                      : '${s.pointsIntoLevel} / ${s.levelPoints} до уровня ${s.level + 1} · всего ${s.points} очков',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Очки: силовая до 120, кардио до 60 (меньше без часов), '
                  'дуэль 5–15, совет дня 10. Награды выдаются сами.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(width: 40),
            const Expanded(
              child: Text(
                'Бесплатно',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  const Icon(LucideIcons.crown, size: 14, color: _gold),
                  const SizedBox(width: 4),
                  const Flexible(
                    child: Text(
                      'Премиум',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final t in s.tiers)
          _TierRow(
            tier: t,
            reached: t.level <= s.level,
            premium: s.premium,
            current: t.level == s.level + 1,
          ),
      ],
    );
  }
}

class _TierRow extends ConsumerWidget {
  const _TierRow({
    required this.tier,
    required this.reached,
    required this.premium,
    required this.current,
  });

  final SeasonTier tier;
  final bool reached;
  final bool premium;
  final bool current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: current ? AppColors.raised : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: current ? accent : AppColors.hairline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: reached
                  ? Icon(LucideIcons.check, size: 18, color: accent)
                  : Text(
                      '${tier.level}',
                      style: figureStyle(
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: _Reward(reward: tier.free, unlocked: reached),
          ),
          Expanded(
            child: _Reward(
              reward: tier.premium,
              unlocked: reached && premium,
              locked: !premium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Награда одной клетки: вещь с превью или монеты и бустеры.
class _Reward extends ConsumerWidget {
  const _Reward({
    required this.reward,
    required this.unlocked,
    this.locked = false,
  });

  final SeasonReward reward;
  final bool unlocked;
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(heroProvider)?.look;
    final item = reward.items.isEmpty
        ? null
        : ShopCatalog.all.where((i) => i.id == reward.items.first).firstOrNull;
    final lines = [
      if (item != null) item.name,
      '+${reward.coins} монет',
      if (reward.xpBoosters > 0) 'бустер опыта',
      if (reward.coinBoosters > 0) 'бустер монет',
    ];
    return Opacity(
      opacity: unlocked ? 1 : (locked ? 0.45 : 0.75),
      child: Row(
        children: [
          if (item != null && look != null) ...[
            ItemPreview(item: item, base: look, size: 34),
            const SizedBox(width: 6),
          ] else if (locked) ...[
            const Icon(LucideIcons.lock, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              lines.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: item != null ? FontWeight.w500 : FontWeight.w400,
                color: item != null
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}
