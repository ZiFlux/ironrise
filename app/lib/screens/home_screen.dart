import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_view.dart';
import '../game/body_part.dart';
import '../game/game_config.dart';
import '../game/recommendation.dart';
import '../state/hero.dart';
import '../state/providers.dart';
import '../state/workout_state.dart';
import '../theme.dart';
import '../widgets/level_plate.dart';
import '../widgets/week_strip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();

    final recommendation = Recommendation.forLagging(hero.lagging);
    final isTrainingDay = hero.trainingDays.contains(
      DateTime.now().weekday - 1,
    );

    return Scaffold(
      body: SafeArea(
        // Всё на одном экране без прокрутки: аватар забирает оставшееся место.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(hero: hero),
              Expanded(
                child: AvatarView(
                  levels: hero.levels,
                  look: hero.look,
                  withLamp: true,
                ),
              ),
              WeekStrip(hero: hero),
              const SizedBox(height: 8),
              if (recommendation != null) ...[
                _LaggingCard(
                  recommendation: recommendation,
                  onStart: () {
                    final notifier = ref.read(workoutProvider.notifier)
                      ..start();
                    final exercise = recommendation.exercise;
                    if (exercise != null) notifier.addExercise(exercise);
                    context.go('/workout');
                  },
                ),
                const SizedBox(height: 8),
              ],
              _PlateRow(hero: hero),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  ref.read(workoutProvider.notifier).start();
                  context.go('/workout');
                },
                icon: const Icon(LucideIcons.dumbbell, size: 18),
                label: const Text('Начать тренировку'),
              ),
              if (!isTrainingDay) _RestDayNote(maxRestDays: hero.maxRestDays),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final streak = hero.currentStreak(DateTime.now());
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatToday(DateTime.now()),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hero.nickname,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _StatChip(
          icon: LucideIcons.flame,
          iconColor: AppColors.textSecondary,
          value: Text(
            '$streak',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          semantics: 'Серия $streak дней',
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: LucideIcons.zap,
          iconColor: accent,
          value: Text(
            '${hero.power}',
            style: figureStyle(size: 15, color: accent),
          ),
          semantics: 'Сила ${hero.power}',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.semantics,
  });

  final IconData icon;
  final Color iconColor;
  final Widget value;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            value,
          ],
        ),
      ),
    );
  }
}

class _LaggingCard extends StatelessWidget {
  const _LaggingCard({required this.recommendation, required this.onStart});

  final Recommendation recommendation;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final penalty = ((1 - GameConfig.powerPenaltyUnbalanced) * 100).round();
    final part = recommendation.part;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: part.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.laggingTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${recommendation.text}, опыт ×1,5',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'сила −$penalty%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlateRow extends StatelessWidget {
  const _PlateRow({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context) {
    final lagging = hero.lagging;
    return Row(
      children: [
        for (final (i, part) in BodyPart.values.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: LevelPlate(
              part: part,
              xp: hero.xp[part]!,
              lagging: lagging.contains(part),
              compact: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _RestDayNote extends StatelessWidget {
  const _RestDayNote({required this.maxRestDays});

  final int maxRestDays;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'По графику отдых. Серия не сгорит ещё $maxRestDays дн.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }
}

const _weekdays = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];
const _monthsGenitive = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// «Среда, 11 ноября».
String formatToday(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_monthsGenitive[date.month - 1]}';
