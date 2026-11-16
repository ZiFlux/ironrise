import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/posing_avatar.dart';
import '../game/body_part.dart';
import '../game/game_config.dart';
import '../game/recommendation.dart';
import '../state/account_state.dart';
import '../state/body_log.dart';
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
import '../widgets/weigh_in.dart';
import '../state/entry_test_state.dart';
import '../game/goal_path.dart';
import '../widgets/info_bubble.dart';
import '../widgets/motion.dart';
import '../widgets/shop_entry.dart';
import '../widgets/guide.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();

    final recommendation = Recommendation.forLagging(hero.lagging);
    final today = ref.watch(todayPlanProvider).day;
    // Силовая — только в дни загрузки; у «Минимума» после неё — день восстановления.
    final isTrainingDay = hero.isLoadDay(DateTime.now());
    final isRecoveryDay = hero.isRecoveryDay(DateTime.now());
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
                FadeSlideIn(
                  child: GuideTarget(
                    id: 'home.header',
                    child: _Header(hero: hero),
                  ),
                ),
                FlexibleMin(
                  minHeight: 130,
                  child: GuideTarget(
                    id: 'home.avatar',
                    child: Semantics(
                      button: true,
                      label: 'Открыть гардероб',
                      child: GestureDetector(
                        onTap: () => context.push('/wardrobe'),
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
                ),
                FadeSlideIn(
                  index: 1,
                  child: GuideTarget(
                    id: 'home.week',
                    child: WeekStrip(
                      hero: hero,
                      log: ref.watch(trainingLogProvider),
                    ),
                  ),
                ),
                const _ActivityLine(),
                const _TipLine(),
                const _EntryTestLine(),
                const _WeighInLine(),
                const SizedBox(height: 8),
                // В день отдыха по графику силовую не предлагаем — только кардио.
                if (recommendation != null &&
                    !strengthDone &&
                    isTrainingDay) ...[
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
                  child: GuideTarget(
                    id: 'home.plan',
                    child: Pressable(
                      child: switch ((strengthDone, cardioDone)) {
                        (_, false) when isRecoveryDay => FilledButton.icon(
                          onPressed: () => context.push('/workout/recovery'),
                          icon: const Icon(LucideIcons.leaf, size: 18),
                          label: const Text('День восстановления · 15 минут'),
                        ),
                        (_, false) when !isTrainingDay => FilledButton.icon(
                          onPressed: () => context.push('/workout/cardio'),
                          icon: const Icon(LucideIcons.heartPulse, size: 18),
                          label: const Text('День отдыха · лёгкое кардио'),
                        ),
                        (_, true) when !isTrainingDay => const FilledButton(
                          onPressed: null,
                          child: Text('На сегодня всё — отдыхай'),
                        ),
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
                          onPressed: () => context.push('/workout/cardio'),
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
                ),
                if (isRecoveryDay)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Tappable(
                      onTap: (c) => showInfoBubble(
                        c,
                        title: 'День восстановления',
                        text:
                            'После дня загрузки мышцам нужен лёгкий день: растяжка, '
                            'суставная гимнастика и спокойное кардио — к следующей '
                            'силовой ты сильнее. Необязательно: серия не сгорит и без него.',
                        actionLabel: 'Изменить график',
                        onAction: () =>
                            context.push('/profile/settings/schedule'),
                      ),
                      child: const Text(
                        'После загрузки — лёгкий день: растяжка и кардио, серия продлится',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else if (!isTrainingDay)
                  _RestDayNote(maxRestDays: hero.maxRestDays),
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
                onPressed: () => context.push('/notifications'),
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
                onTap: (_) => showStreakSheet(context),
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
                onTap: (c) => showInfoBubble(
                  c,
                  title: 'Сила ${hero.power}',
                  text:
                      'Растёт только от тренировок: 10 за каждый уровень частей тела '
                      'и 2 за день серии (до 30). Ровное развитие даёт +5%, сильный '
                      'перекос — −10%. Сила решает в дуэлях и лиге.',
                  actionLabel: 'Уровни частей тела',
                  onAction: () => context.go('/profile'),
                ),
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
                onTap: (_) => context.push('/shop'),
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

  /// Получает контекст плашки — для облака рядом с ней (п. 127).
  final void Function(BuildContext context)? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
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
    );
    final tap = onTap;
    return tap == null
        ? Semantics(label: semantics, excludeSemantics: true, child: chip)
        : Tappable(
            semantics: semantics,
            onTap: tap,
            child: ExcludeSemantics(child: chip),
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
      child: Tappable(
        onTap: (c) => showInfoBubble(
          c,
          title: 'День отдыха',
          text:
              'Мышцы растут, пока ты отдыхаешь. Подряд без тренировки можно '
              '$maxRestDays дн. — серия не сгорит. Лёгкое кардио в отдых '
              'тоже качает героя, но необязательно.',
          actionLabel: 'Изменить график',
          onAction: () => context.push('/profile/settings/schedule'),
        ),
        child: Text(
          'По графику отдых. Серия не сгорит ещё $maxRestDays дн.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
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
      child: Tappable(
        onTap: (c) => showInfoBubble(
          c,
          title: 'Шаги за сегодня',
          text:
              'Берутся из Health Connect (часы или телефон). В день отдыха '
              'вечером шаги дают опыт кардио: 3 опыта за каждую тысячу, до 30.',
          actionLabel: 'Устройства',
          onAction: () => context.push('/profile/devices'),
        ),
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
      ),
    );
  }
}

/// «Совет дня» одной строкой: открывает совет, показывает, получена ли награда.
/// Входная тренировка (п. 116): пока не пройдена — настойчиво (после «позже» — через
/// день), через 4 недели — «пора сравнить».
class _EntryTestLine extends ConsumerWidget {
  const _EntryTestLine();

  /// Строка видна: первая не пройдена или пора повторить (и не отложено на сегодня).
  static ({bool first, bool retest}) due(WidgetRef ref) {
    ref.watch(entryTestProvider);
    final tests = ref.read(entryTestProvider.notifier);
    final now = DateTime.now();
    final snoozed = tests.snoozed(now);
    return (
      first: tests.firstDue && !snoozed,
      retest: tests.retestDue(now) && !snoozed,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:first, :retest) = due(ref);
    if (!first && !retest) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: accent.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: () => context.push('/entry-test'),
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(LucideIcons.clipboardCheck, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      first
                          ? 'Входная тренировка · 12 мин · +50 монет'
                          : 'Месяц прошёл — сравним, как ты вырос',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.textMuted,
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

/// «Пора взвеситься» — раз в 3 дня, пока вес не записан.
class _WeighInLine extends ConsumerWidget {
  const _WeighInLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Одно напоминание за раз: главная без прокрутки, входная тренировка важнее.
    final entry = _EntryTestLine.due(ref);
    if (entry.first ||
        entry.retest ||
        !weighInDue(
          ref.watch(bodyLogProvider),
          DateTime.now(),
          // При цели «похудеть» — раз в 2 дня (п. 117).
          every: weighInEveryFor(
            ref.watch(heroProvider)?.goal,
            ref.watch(heroProvider)?.extraGoals ?? const [],
          ),
        )) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.hairline),
        ),
        child: InkWell(
          onTap: () => showWeighIn(context, ref),
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.scale,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Пора взвеситься — и анализ тела на часах',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.textMuted,
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
          onTap: () => context.push('/tip'),
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
