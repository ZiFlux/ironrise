import 'format.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/shop.dart';
import '../game/streak_rewards.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'item_preview.dart';

const _flame = Color(0xFFFF8A3D);

/// Серия и её награды: что дадут завтра, ближайший рубеж, бустеры, вся таблица.
Future<void> showStreakSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        // Тянется вниз за полоску и за содержимое, когда список вверху.
        builder: (_, scroll) => _StreakSheet(scroll: scroll),
      ),
    );

class _StreakSheet extends ConsumerWidget {
  const _StreakSheet({required this.scroll});

  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final streak = hero.currentStreak(DateTime.now());
    final next = nextMilestone(streak);
    final prev = streakMilestones
        .where((m) => m.day <= streak)
        .fold(0, (d, m) => m.day > d ? m.day : d);
    final progress = (streak - prev) / (next.day - prev);
    final boosters = hero.boosters;
    return SafeArea(
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              const Icon(LucideIcons.flame, color: _flame, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Серия $streak',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Продли тренировкой по графику — +${dailyStreakCoins(streak + 1)} монет'
            '${milestoneFor(streak + 1) != null ? ' и награда рубежа' : ''}. '
            'Отдых по графику серию не сжигает',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (streak == 0 && hero.lastActiveDay != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Серия прервалась — ничего страшного. Первая тренировка после паузы '
              'даст +25% опыта',
              style: TextStyle(fontSize: 13, color: _flame),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'До рубежа в ${daysWord(next.day)} осталось ${daysWord(next.day - streak)}',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              color: _flame,
              backgroundColor: AppColors.raised,
            ),
          ),
          if (!boosters.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.rocket, size: 18, color: _flame),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        if (boosters.xp > 0) 'опыт ×1,5 — ${boosters.xp}',
                        if (boosters.coins > 0) 'монеты ×2 — ${boosters.coins}',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Бустеры срабатывают сами на следующей тренировке, по одному',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Рубежи',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          for (final m in streakMilestones)
            _MilestoneRow(milestone: m, reached: streak >= m.day),
          const SizedBox(height: 8),
          const Text(
            'Дальше — каждые 30 дней: 250 монет, 200 опыта и оба бустера',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends ConsumerWidget {
  const _MilestoneRow({required this.milestone, required this.reached});

  final StreakMilestone milestone;
  final bool reached;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = milestone;
    final item = m.item == null ? null : ShopCatalog.byId(m.item!);
    final look = ref.watch(heroProvider)?.look;
    final parts = [
      '+${m.coins} монет',
      if (m.xp > 0) '+${m.xp} опыта',
      if (m.boosters.xp > 0) 'бустер опыта',
      if (m.boosters.coins > 0) 'бустер монет',
      if (item != null) '${item.slot.label.toLowerCase()} «${item.name}»',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: reached
                  ? _flame.withValues(alpha: 0.18)
                  : AppColors.raised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${m.day}',
              style: figureStyle(
                size: 14,
                color: reached ? _flame : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: TextStyle(
                fontSize: 13,
                color: reached ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ),
          if (item != null && look != null)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.raised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ItemPreview(item: item, base: look, size: 40),
            ),
          if (reached)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(LucideIcons.check, size: 16, color: _flame),
            ),
        ],
      ),
    );
  }
}

/// Карточка на итогах тренировки: серия выросла — что получено.
class StreakRewardCard extends ConsumerWidget {
  const StreakRewardCard({super.key, required this.reward});

  final StreakReward reward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [for (final id in reward.items) ShopCatalog.byId(id)];
    final look = ref.watch(heroProvider)?.look;
    final lines = [
      '+${reward.coins} монет',
      if (reward.xp > 0) '+${reward.xp} опыта отстающей части',
      if (reward.boosters.xp > 0) 'бустер опыта ×1,5',
      if (reward.boosters.coins > 0) 'бустер монет ×2',
      for (final i in items)
        'новая вещь: ${i.slot.label.toLowerCase()} «${i.name}»',
    ];
    return Card(
      child: InkWell(
        onTap: () => showStreakSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(LucideIcons.flame, color: _flame, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.milestones.isEmpty
                          ? 'Серия ${reward.streak}'
                          : 'Рубеж серии: ${reward.milestones.last} дней!',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lines.join(' · '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty && look != null)
                ItemPreview(item: items.first, base: look, size: 44),
            ],
          ),
        ),
      ),
    );
  }
}
