import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/posing_avatar.dart';
import '../game/body_part.dart';
import '../game/game_config.dart';
import '../game/recommendation.dart';
import '../state/account_state.dart';
import '../state/health_state.dart';
import '../state/hero.dart';
import '../state/program_state.dart';
import '../state/providers.dart';
import '../state/tips_state.dart';
import '../state/server_game.dart';
import '../state/workout_state.dart';
import '../game/training_stats.dart';
import '../state/training_log.dart';
import '../widgets/streak_sheet.dart';
import '../theme.dart';
import '../widgets/fit_screen.dart';
import '../widgets/format.dart';
import '../widgets/body_part_sheet.dart';
import '../widgets/level_plate.dart';
import '../widgets/week_strip.dart';
import '../widgets/motion.dart';
import '../widgets/shop_entry.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();

    final recommendation = Recommendation.forLagging(hero.lagging);
    final today = ref.watch(todayPlanProvider).day;
    final isTrainingDay = hero.trainingDays.contains(
      DateTime.now().weekday - 1,
    );
    // В день — одна силовая и одно кардио: после силовой план не предлагаем.
    final log = ref.watch(trainingLogProvider);
    final strengthDone = doneToday(log, WorkoutKind.strength, DateTime.now());
    final cardioDone = doneToday(log, WorkoutKind.cardio, DateTime.now());

    return Scaffold(
      body: SafeArea(
        // Всё на одном экране без прокрутки: аватар забирает оставшееся место.
        // На маленьком экране или с крупным шрифтом — прокрутка вместо наложения.
        child: FitScreen(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(child: _Header(hero: hero)),
                FlexibleMin(
                  minHeight: 130,
                  child: Semantics(
                    button: true,
                    label: 'Открыть гардероб',
                    child: GestureDetector(
                      onTap: () => context.go('/wardrobe'),
                      child: PosingAvatar(
                        levels: hero.avatarLevels,
                        look: hero.look,
                        muscles: hero.muscles,
                        focus: recentMuscles(
                          ref.watch(trainingLogProvider),
                          DateTime.now(),
                        ),
                        withLamp: true,
                      ),
                    ),
                  ),
                ),
                FadeSlideIn(index: 1, child: WeekStrip(hero: hero)),
                const _ActivityLine(),
                const _TipLine(),
                const SizedBox(height: 8),
                if (recommendation != null && !strengthDone) ...[
                  FadeSlideIn(
                    index: 2,
                    child: _LaggingCard(
                      recommendation: recommendation,
                      onStart: () {
                        final notifier = ref.read(workoutProvider.notifier)
                          ..start();
                        final exercise = recommendation.exercise;
                        if (exercise != null) notifier.addExercise(exercise);
                        context.go('/workout');
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FadeSlideIn(index: 3, child: _PlateRow(hero: hero)),
                const SizedBox(height: 12),
                FadeSlideIn(
                  index: 4,
                  child: Pressable(
                    child: switch ((strengthDone, cardioDone)) {
                      (false, _) => FilledButton.icon(
                        onPressed: () {
                          ref
                              .read(workoutProvider.notifier)
                              .startPlanned(today);
                          context.go('/workout');
                        },
                        icon: const Icon(LucideIcons.dumbbell, size: 18),
                        label: Text(planLabel(today)),
                      ),
                      (true, false) => OutlinedButton.icon(
                        onPressed: () => context.go('/workout/cardio'),
                        icon: const Icon(LucideIcons.heartPulse, size: 18),
                        label: const Text('Силовая сделана · кардио'),
                      ),
                      (true, true) => const FilledButton(
                        onPressed: null,
                        child: Text('На сегодня всё — отдыхай'),
                      ),
                    },
                  ),
                ),
                if (!isTrainingDay) _RestDayNote(maxRestDays: hero.maxRestDays),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    final streak = hero.currentStreak(DateTime.now());
    final signedIn = ref.watch(accountProvider).signedIn;
    final unread = signedIn
        ? ref.watch(notificationsProvider).value?.unread ?? 0
        : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => context.go('/profile'),
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatToday(DateTime.now()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hero.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const ShopButton(),
            if (signedIn)
              IconButton(
                tooltip: unread > 0
                    ? 'Уведомления: $unread новых'
                    : 'Уведомления',
                onPressed: () => context.go('/notifications'),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(LucideIcons.bell, size: 22),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: _StatChip(
                onTap: () => showStreakSheet(context),
                icon: LucideIcons.flame,
                iconColor: AppColors.textSecondary,
                value: AnimatedNumber(
                  value: streak,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                semantics: 'Серия $streak дней',
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _StatChip(
                icon: LucideIcons.zap,
                iconColor: accent,
                value: AnimatedNumber(
                  value: hero.power,
                  style: figureStyle(size: 15, color: accent),
                ),
                semantics: 'Сила ${hero.power}',
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _StatChip(
                icon: LucideIcons.coins,
                iconColor: AppColors.textSecondary,
                value: AnimatedNumber(
                  value: hero.coins,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                semantics: 'Монеты ${hero.coins}, открыть магазин',
                onTap: () => context.go('/shop'),
              ),
            ),
          ],
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
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Widget value;
  final String semantics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Semantics(
      label: semantics,
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
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
              // Большие числа и крупный шрифт — уменьшаем, а не вылезаем за плашку.
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, child: value),
              ),
            ],
          ),
        ),
      ),
    );
    return onTap == null ? chip : Pressable(child: chip);
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _PlateRow extends ConsumerWidget {
  const _PlateRow({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lagging = hero.lagging;
    // Что качается чаще всего за две недели — «горит».
    final hot = hotParts(
      ref.watch(trainingLogProvider),
      DateTime.now(),
      muscles: hero.muscles,
    );
    return Row(
      children: [
        for (final (i, part) in BodyPart.values.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: LevelPlate(
              hot: hot.contains(part),
              onTap: () => showBodyPartSheet(context, part),
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

/// Шаги и расстояние за сегодня с часов (Health Connect). Без подключения — пусто.
class _ActivityLine extends ConsumerWidget {
  const _ActivityLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider);
    final steps = health.stepsToday;
    if (!health.connected || steps == null) return const SizedBox.shrink();
    final km = ((health.metersToday ?? 0) / 1000)
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.footprints,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${formatThousands(steps)} шагов · $km км сегодня',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Совет дня» одной строкой: открывает совет, показывает, получена ли награда.
class _TipLine extends ConsumerWidget {
  const _TipLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(tipsProvider);
    if (daily == null) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final fresh = !daily.done;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.hairline),
        ),
        child: InkWell(
          onTap: () => context.go('/tip'),
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // Непрочитанный совет — лампочка горит и с точкой, как значок
                  // нового сообщения; после ответа строка гаснет.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        LucideIcons.lightbulb,
                        size: 16,
                        color: fresh ? accent : AppColors.textMuted,
                      ),
                      if (fresh)
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Советы дня: ',
                            style: TextStyle(
                              fontWeight: fresh
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                          TextSpan(
                            text: fresh
                                ? '${daily.answeredCount} из ${daily.tips.length} · '
                                      '${daily.tips.firstWhere((t) => !daily.answered(t)).title}'
                                : 'верно ${daily.correctCount} из ${daily.tips.length}',
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: fresh
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (daily.done)
                    const Icon(
                      LucideIcons.check,
                      size: 16,
                      color: AppColors.textMuted,
                    )
                  else
                    Text(
                      'до +${daily.maxCoins}',
                      style: TextStyle(fontSize: 13, color: accent),
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
