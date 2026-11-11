import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_view.dart';
import '../game/body_part.dart';
import '../game/game_config.dart';
import '../state/hero.dart';
import '../state/providers.dart';
import '../state/workout_state.dart';
import '../theme.dart';
import '../widgets/level_plate.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();

    final lagging = hero.lagging;
    final isTrainingDay = hero.trainingDays.contains(DateTime.now().weekday - 1);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _Header(hero: hero),
            const SizedBox(height: 8),
            SizedBox(
              height: 272,
              child: AvatarView(levels: hero.levels, look: hero.look, withLamp: true),
            ),
            const SizedBox(height: 8),
            if (lagging.isNotEmpty) ...[
              _LaggingCard(part: lagging.first),
              const SizedBox(height: 16),
            ],
            _PlateGrid(hero: hero),
            const SizedBox(height: 20),
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatToday(DateTime.now()),
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(hero.nickname, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        _StatChip(
          icon: LucideIcons.flame,
          iconColor: AppColors.textSecondary,
          value: Text('${hero.streakDays}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          semantics: 'Серия ${hero.streakDays} дней',
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: LucideIcons.zap,
          iconColor: accent,
          value: Text('${hero.power}', style: figureStyle(size: 15, color: accent)),
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
  const _LaggingCard({required this.part});

  final BodyPart part;

  @override
  Widget build(BuildContext context) {
    final penalty = ((1 - GameConfig.powerPenaltyUnbalanced) * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: part.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(part.laggingTitle,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${part.beginnerExercise}, опыт ×1,5',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text('сила −$penalty%',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _PlateGrid extends StatelessWidget {
  const _PlateGrid({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context) {
    final lagging = hero.lagging;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: [
        for (final part in BodyPart.values)
          LevelPlate(part: part, xp: hero.xp[part]!, lagging: lagging.contains(part)),
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
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Сегодня по графику отдых. До $maxRestDays дн. отдыха подряд серия не сгорает',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }
}

const _weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
const _monthsGenitive = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

/// «Среда, 11 ноября».
String formatToday(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_monthsGenitive[date.month - 1]}';
