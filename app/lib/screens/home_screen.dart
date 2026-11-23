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
                // Герой — главная фишка: около 60 % экрана. Показатели — колонкой
                // слева, дела дня — кнопками справа, как экран персонажа в игре.
                FlexibleMin(
                  minHeight: 220,
                  child: GuideTarget(
                    id: 'home.avatar',
                    child: Stack(
                      children: [
                        Positioned.fill(
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
                        Positioned(
                          left: 0,
                          top: 8,
                          child: FadeSlideIn(child: _HeroStats(hero: hero)),
                        ),
                        const Positioned(
                          right: 0,
                          top: 8,
                          child: FadeSlideIn(index: 1, child: _TodayRow()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
                        (_, true) when !isTrainingDay => const _DayDone(),
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
                        (true, true) => const _DayDone(),
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
    final signedIn = ref.watch(accountProvider).signedIn;
    final unread = signedIn
        ? ref.watch(notificationsProvider).value?.unread ?? 0
        : 0;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                hero.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const ShopButton(),
        if (signedIn)
          IconButton(
            tooltip: unread > 0 ? 'Уведомления: $unread новых' : 'Уведомления',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(LucideIcons.bell, size: 22),
            ),
          ),
      ],
    );
  }
}

/// Показатели героя колонкой слева от него: серия, сила, монеты и шаги.
/// Без плашек — тихо, чтобы не спорить с героем; каждое нажимается.
class _HeroStats extends ConsumerWidget {
  const _HeroStats({required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final streak = hero.currentStreak(DateTime.now());
    final health = ref.watch(healthProvider);
    final steps = health.connected ? health.stepsToday : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatChip(
          onTap: (_) => showStreakSheet(context),
          icon: LucideIcons.flame,
          iconColor: scheme.tertiary,
          label: streakLabel(streak),
          value: AnimatedNumber(
            value: streak,
            style: figureStyle(size: 20, color: scheme.tertiary),
          ),
          semantics: 'Серия $streak дней',
        ),
        _StatChip(
          icon: LucideIcons.zap,
          iconColor: scheme.secondary,
          label: 'сила',
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
            style: figureStyle(size: 20, color: scheme.secondary),
          ),
          semantics: 'Сила ${hero.power}',
        ),
        _StatChip(
          icon: LucideIcons.coins,
          iconColor: AppColors.textSecondary,
          label: 'монет',
          value: AnimatedNumber(
            value: hero.coins,
            style: figureStyle(size: 20),
          ),
          semantics: 'Монеты ${hero.coins}, открыть магазин',
          onTap: (_) => context.push('/shop'),
        ),
        if (steps != null)
          _StatChip(
            icon: LucideIcons.footprints,
            iconColor: AppColors.textSecondary,
            label: 'шагов',
            value: Text(formatThousands(steps), style: figureStyle(size: 16)),
            semantics: '${formatThousands(steps)} шагов сегодня',
            onTap: (c) => showInfoBubble(
              c,
              title: 'Шаги за сегодня',
              text:
                  'Берутся из Health Connect (часы или телефон). В день отдыха '
                  'вечером шаги дают опыт кардио: 3 опыта за каждую тысячу, до 30.',
              actionLabel: 'Устройства',
              onAction: () => context.push('/profile/devices'),
            ),
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
    required this.label,
    required this.semantics,
    this.onTap,
  });

  /// Что за число — подпись под ним («дн. серии», «сила», «монет»).
  final String label;

  final IconData icon;
  final Color iconColor;
  final Widget value;
  final String semantics;

  /// Получает контекст плашки — для облака рядом с ней (п. 127).
  final void Function(BuildContext context)? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              value,
            ],
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
              '${daysWord(maxRestDays)} — серия не сгорит. Лёгкое кардио в отдых '
              'тоже качает героя, но необязательно.',
          actionLabel: 'Изменить график',
          onAction: () => context.push('/profile/settings/schedule'),
        ),
        child: Text(
          'По графику отдых. Серия не сгорит ещё ${daysWord(maxRestDays)}',
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

/// «1 день серии», «2 дня», «5 дней» — подпись под числом серии.
String streakLabel(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'день серии';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'дня серии';
  }
  return 'дней серии';
}

/// Ряд «Сегодня» под героем: входная тренировка, советы дня, взвешивание.
/// Что ждёт действия — с точкой и иконкой акцентом, остальное — тихо.
/// Раньше это были квадраты за спиной героя (docs/REDESIGN.md).
class _TodayRow extends ConsumerWidget {
  const _TodayRow();

  /// Входная тренировка: первая не пройдена или пора повторить (и не отложено на сегодня).
  static ({bool first, bool retest}) entryDue(WidgetRef ref) {
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
    final daily = ref.watch(tipsProvider);
    final entry = entryDue(ref);
    final hero = ref.watch(heroProvider);
    final weighDue = weighInDue(
      ref.watch(bodyLogProvider),
      DateTime.now(),
      // При цели «похудеть» — раз в 2 дня (п. 117).
      every: weighInEveryFor(hero?.goal, hero?.extraGoals ?? const []),
    );
    final items = [
      if (entry.first || entry.retest)
        _TodayItem(
          icon: LucideIcons.clipboardCheck,
          label: 'Тест',
          hint: entry.first
              ? 'Входная тренировка · 12 мин · +50 монет'
              : 'Прошёл месяц — пора сравнить результаты',
          due: true,
          onTap: () => context.push('/entry-test'),
        ),
      if (daily != null)
        _TodayItem(
          icon: LucideIcons.lightbulb,
          label: 'Советы',
          hint: daily.done
              ? 'Советы дня: верно ${daily.correctCount} из ${daily.tips.length}'
              : 'Советы дня: ${daily.answeredCount} из ${daily.tips.length}, до +${daily.maxCoins} монет',
          due: !daily.done,
          onTap: () => context.push('/tip'),
        ),
      _TodayItem(
        icon: LucideIcons.scale,
        label: 'Вес',
        hint: weighDue
            ? 'Пора взвеситься и сделать анализ тела на часах'
            : 'Записать вес и состав тела',
        due: weighDue,
        onTap: () => showWeighIn(context, ref),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          item,
        ],
      ],
    );
  }
}

class _TodayItem extends StatelessWidget {
  const _TodayItem({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.due = false,
  });

  final IconData icon;
  final String label;

  /// Для экранного диктора и долгого нажатия — полная подпись.
  final String hint;
  final VoidCallback onTap;

  /// Ждёт действия — точка и иконка цветом акцента.
  final bool due;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: hint,
      child: Semantics(
        button: true,
        label: hint,
        excludeSemantics: true,
        child: Pressable(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onTap,
                      customBorder: const CircleBorder(),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Icon(
                          icon,
                          size: 20,
                          color: due ? accent : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  // Ждёт действия — точка в углу, как значок.
                  if (due)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: due ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// День закрыт: статус вместо выключенной серой кнопки (она читалась как «сломано»).
class _DayDone extends StatelessWidget {
  const _DayDone();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 48,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.circleCheck, size: 18, color: AppColors.success),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            'На сегодня всё — отдыхай',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}
