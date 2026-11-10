import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../game/body_part.dart';
import '../game/training_format.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/avatar_view.dart';
import '../widgets/part_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();

    final levels = hero.levels;
    final lagging = hero.lagging;
    final todayIndex = DateTime.now().weekday - 1;
    final isTrainingDay = hero.trainingDays.contains(todayIndex);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Шапка: ник, сила, серия
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hero.nickname,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(hero.goal.label,
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                _Stat(icon: Icons.bolt, value: '${hero.power}', label: 'сила',
                    color: AppColors.accent),
                const SizedBox(width: 12),
                _Stat(icon: Icons.local_fire_department, value: '${hero.streakDays}',
                    label: 'серия', color: const Color(0xFFFFC23D)),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 320,
              child: AvatarView(levels: levels, lagging: lagging),
            ),

            if (lagging.isNotEmpty) ...[
              _LaggingBanner(part: lagging.first),
              const SizedBox(height: 12),
            ],

            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    for (final p in BodyPart.values)
                      PartBar(part: p, xp: hero.xp[p]!, lagging: lagging.contains(p)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            _WeekStrip(trainingDays: hero.trainingDays, today: todayIndex),
            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: () => context.go('/workout'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(isTrainingDay ? 'Начать тренировку' : 'Тренировка вне графика'),
            ),
            if (!isTrainingDay)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Сегодня по графику отдых. Отдых до ${hero.maxRestDays} дн. подряд серию не сбрасывает.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label, required this.color});

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _LaggingBanner extends StatelessWidget {
  const _LaggingBanner({required this.part});

  final BodyPart part;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: part.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: part.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(part.icon, color: part.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Отстаёт: ${part.label}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: part.color)),
                const SizedBox(height: 2),
                Text('Сегодня: ${part.beginnerExercise}. Опыт ×1,5, сила −10% пока есть перекос',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.trainingDays, required this.today});

  final List<int> trainingDays;
  final int today;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Column(
            children: [
              Text(weekdayShort[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: i == today ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: i == today ? FontWeight.w700 : FontWeight.w400,
                  )),
              const SizedBox(height: 6),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trainingDays.contains(i)
                      ? AppColors.accent.withValues(alpha: i == today ? 1 : 0.25)
                      : AppColors.surface,
                  border: i == today ? Border.all(color: AppColors.textPrimary, width: 1.5) : null,
                ),
                child: Icon(
                  trainingDays.contains(i) ? Icons.fitness_center : Icons.bedtime_outlined,
                  size: 16,
                  color: trainingDays.contains(i) ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
