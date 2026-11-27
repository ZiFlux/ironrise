import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../state/rest_state.dart';
import '../avatar/avatar_look.dart';
import '../game/set_sanity.dart';
import '../state/records_state.dart';
import '../game/to_failure.dart';
import '../game/exercise_catalog.dart';
import '../game/program.dart';
import '../game/recommendation.dart';
import '../game/training_stats.dart';
import '../game/game_config.dart';
import '../game/set_effort.dart';
import '../game/warmup.dart';
import '../game/wellbeing.dart';
import '../game/workout.dart';
import '../game/workout_variant.dart';
import '../state/training_sound.dart';
import '../state/hero.dart';
import '../game/training_format.dart';
import '../state/cardio_state.dart';
import '../state/heart_rate_state.dart';
import '../state/program_state.dart';
import '../state/joint_state.dart';
import '../state/providers.dart';
import '../state/workout_state.dart';
import '../state/training_log.dart';
import '../state/aura_state.dart';
import '../widgets/aura_flame.dart';
import '../theme.dart';
import '../widgets/every_second.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/struggle_sheet.dart';
import '../widgets/skill_goals.dart';
import '../game/exercise_swap.dart';
import '../widgets/format.dart';
import '../widgets/warmup_card.dart';
import '../widgets/guide.dart';
import '../widgets/delayed_confirm.dart';
import '../widgets/info_bubble.dart';
import '../game/set_pulse.dart';
import '../game/skill_practice.dart';
import '../game/circuit_rest.dart';
import '../game/anti_fraud.dart' show PulseSample;

class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutProvider);
    return session == null
        ? const _StartView()
        : _ActiveWorkout(session: session);
  }
}

// ---------- Тренировка не начата ----------

/// «Фаза «Старт» · 5 из 12 тренировок» или «Фаза «База»».
/// «3 × 8–12» или «3 × 30 с» для упражнений на время.
String _setsLine(PlannedExercise e) {
  final reps = e.repsMin == e.repsMax
      ? '${e.repsMin}'
      : '${e.repsMin}–${e.repsMax}';
  final unit = e.exercise.unit == ExerciseUnit.seconds ? ' с' : '';
  return '${e.sets} × $reps$unit';
}

String _phaseLine(UserProgram program, HeroProfile? hero) {
  final level = trainingLevelOf(hero, program);
  return switch (program.phaseFor(level)) {
    ProgramPhase.start =>
      'Фаза «Старт» · ${program.completedWorkouts} из ${ProgramPhase.startWorkouts} тренировок: техника, 2 подхода',
    ProgramPhase.base =>
      'Уровень «${level.label}»: ${level.exercises} упражнений, '
          '~${level.weeklySets} подходов на мышцу в неделю',
  };
}

/// Облако к строке фазы (п. 127): что значит фаза и как растёт нагрузка.
String _phaseExplain(UserProgram program, HeroProfile? hero) {
  final level = trainingLevelOf(hero, program);
  final phase = switch (program.phaseFor(level)) {
    ProgramPhase.start =>
      'Первые ${ProgramPhase.startWorkouts} тренировок — «Старт»: по 2 подхода, '
          'учимся технике и подбираем вес. Связки и суставы привыкают медленнее мышц, '
          'поэтому начинаем мягко.',
    ProgramPhase.base =>
      'Уровень «${level.label}» по твоему опыту: ${level.exercises} упражнений и '
          'около ${level.weeklySets} подходов на мышцу в неделю. С опытом уровень '
          'растёт, а раз в несколько недель план сам облегчается — разгрузка.',
  };
  return '$phase\n\nРазминка: сначала суставы сверху вниз, потом мышцы, которые сегодня '
      'работают больше всего, — так меньше риск растяжений.';
}

/// Неделя по графику: какой день что тренировать (п. 127).
Future<void> _showWeekPlan(
  BuildContext context,
  UserProgram program,
  HeroProfile? hero,
) {
  final layout = hero == null
      ? const <({int weekday, String title})>[]
      : weekLayout(
          days: program.days(
            hero.loadDays.length,
            format: hero.format,
            adjacent: hasAdjacentDays(hero.loadDays),
            weekdays: hero.loadDays,
            level: trainingLevelOf(hero, program),
          ),
          nextIndex: program.nextDayIndex,
          trainingDays: hero.loadDays,
          today: DateTime.now(),
        );
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      // 6–7 тренировочных дней не помещаются — прокрутка.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Неделя по графику',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Мышцам нужно 48 часов отдыха, поэтому группы чередуются по дням.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            for (final d in layout)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        weekdayShort[d.weekday],
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        d.title,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheet);
                context.push('/profile/settings/schedule');
              },
              icon: const Icon(LucideIcons.calendarCog, size: 18),
              label: const Text('Изменить график'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Раскладка недели: какой день что тренировать — «Пн верх · Вт низ · Чт верх…»
/// (TRAINING_SYSTEM.md 14). У «всего тела» без смены групп — не показываем.
String? _splitLine(UserProgram program, HeroProfile? hero) {
  if (hero == null) return null;
  final days = program.days(
    hero.loadDays.length,
    format: hero.format,
    adjacent: hasAdjacentDays(hero.loadDays),
    weekdays: hero.loadDays,
    level: trainingLevelOf(hero, program),
  );
  if (days.every((d) => d.title.startsWith('Всё тело'))) return null;
  final layout = weekLayout(
    days: days,
    nextIndex: program.nextDayIndex,
    trainingDays: hero.loadDays,
    today: DateTime.now(),
  );
  return layout
      .map((d) => '${weekdayShort[d.weekday]} ${d.title.toLowerCase()}')
      .join(' · ');
}

class _StartView extends ConsumerWidget {
  const _StartView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = Recommendation.forLagging(
      ref.watch(heroProvider)?.lagging ?? const [],
    );
    final adapted = ref.watch(todayPlanProvider);
    final program = ref.watch(programProvider);
    final today = adapted.day;
    final log = ref.watch(trainingLogProvider);
    final now = DateTime.now();
    final strengthDone = doneToday(log, WorkoutKind.strength, now);
    final cardioDone = doneToday(log, WorkoutKind.cardio, now);
    // День отдыха по графику: предлагаем кардио, силовая — только по желанию.
    final restDay =
        !strengthDone && !(ref.watch(heroProvider)?.isLoadDay(now) ?? true);
    final recoveryDay = ref.watch(heroProvider)?.isRecoveryDay(now) ?? false;
    final level = trainingLevelOf(ref.watch(heroProvider), program);
    final rhythm = Periodization.available(level, trial: program.rhythmTrial);
    final sessions = ref.watch(heroProvider)?.loadDays.length ?? 3;
    final untilDeload = Periodization.untilDeload(
      level: level,
      completedWorkouts: program.completedWorkouts,
      sessionsPerWeek: sessions,
    );
    final notes = [
      if (rhythm) '${adapted.variant.label}: ${adapted.variant.description}',
      if (rhythm && untilDeload > 0)
        'До разгрузочной недели — ${workoutsWord(untilDeload)}',
      ?_splitLine(program, ref.watch(heroProvider)),
      if (adapted.eased) 'План облегчён: на подход меньше',
      if (adapted.boosted) 'План усилен: на подход больше',
      if (ref.watch(heroProvider) case final h?
          when h.lastActiveDay != null && h.currentStreak(DateTime.now()) == 0)
        'Возвращение после паузы: +25% опыта за эту тренировку',
      if ((ref.watch(heroProvider)?.boosters.xp ?? 0) > 0)
        'Бустер серии: опыт ×1,5 за эту тренировку',
      if ((ref.watch(heroProvider)?.boosters.coins ?? 0) > 0)
        'Бустер серии: монеты ×2 за эту тренировку',
      if (adapted.adjustments.any((a) => a.reason == AdjustReason.pain))
        'Часть упражнений заменена, пока бережём больное место',
      if (adapted.adjustments.any((a) => a.reason == AdjustReason.dislike))
        'Что не зашло — заменено похожим',
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировка'),
        actions: [
          GuideTarget(
            id: 'workout.stats',
            child: TextButton.icon(
              onPressed: () => context.push('/workout/stats'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              icon: const Icon(LucideIcons.chartColumn, size: 18),
              label: const Text('Итоги'),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/workout/exercises'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            icon: const Icon(LucideIcons.bookOpen, size: 18),
            label: const Text('Техника'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // План дня — сверху и целиком: что делать и сколько, нажатие — техника.
            // Карточка берёт высоту по содержимому, кнопки остаются внизу.
            Expanded(
              child: GuideTarget(
                id: 'workout.plan',
                // Всё прокручиваемо: «потяни вниз — синхронизация» работает и в день отдыха.
                child: strengthDone
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: _DoneToday(log: log, next: today),
                      )
                    : restDay
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RestDayCard(
                              next: today.title,
                              recoveryDay: recoveryDay,
                              cardioDone: cardioDone,
                              cardioActive: ref.watch(cardioProvider) != null,
                            ),
                            // Отработка — хоть в день отдыха: отдельный комплекс.
                            if (program.skillGoals.isNotEmpty)
                              const Card(
                                clipBehavior: Clip.antiAlias,
                                child: SkillGoalsPanel(),
                              ),
                          ],
                        ),
                      )
                    : Align(
                        alignment: Alignment.topCenter,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListView(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: [
                              // Нажатие — неделя по графику (п. 127).
                              Tappable(
                                onTap: (_) => _showWeekPlan(
                                  context,
                                  program,
                                  ref.read(heroProvider),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Сегодня · ${today.title}',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        LucideIcons.calendarDays,
                                        size: 18,
                                        color: AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Ритм опытных: вид тренировки можно поменять на сегодня.
                              if (rhythm)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    8,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    children: [
                                      for (final v in WorkoutVariant.values)
                                        ChoiceChip(
                                          label: Text(v.label),
                                          selected: adapted.variant == v,
                                          onSelected: (_) => ref
                                              .read(programProvider.notifier)
                                              .overrideVariant(v),
                                        ),
                                    ],
                                  ),
                                ),
                              Tappable(
                                onTap: (c) => showInfoBubble(
                                  c,
                                  title: 'Как устроен план',
                                  text: _phaseExplain(
                                    program,
                                    ref.read(heroProvider),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    8,
                                  ),
                                  child: Text(
                                    [
                                      _phaseLine(
                                        program,
                                        ref.watch(heroProvider),
                                      ),
                                      warmupSummary(
                                        Warmup.forExercises([
                                          for (final e in today.exercises)
                                            e.exercise,
                                        ], program.equipment),
                                      ),
                                      ...notes,
                                    ].join('\n'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              for (final e in today.exercises)
                                InkWell(
                                  onTap: () =>
                                      showExerciseDetails(context, e.exercise),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 48,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: AppColors.hairline,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  e.exercise.name,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                if (skillNote(e)
                                                    case final note?)
                                                  Text(
                                                    note,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _setsLine(e),
                                          style: figureStyle(
                                            size: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SkillGoalsPanel(canStart: false),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (restDay) ...[
              TextButton(
                onPressed: () =>
                    ref.read(workoutProvider.notifier).startPlanned(today),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Всё равно силовая сегодня'),
              ),
              const SizedBox(height: 8),
              _JointButton(),
            ] else ...[
              if (!strengthDone) ...[
                GuideTarget(
                  id: 'workout.start',
                  child: FilledButton(
                    onPressed: () =>
                        ref.read(workoutProvider.notifier).startPlanned(today),
                    child: Text(planLabel(today)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    final notifier = ref.read(workoutProvider.notifier)
                      ..start();
                    final exercise = rec?.exercise;
                    if (exercise != null) notifier.addExercise(exercise);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Без плана'),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: cardioDone && ref.watch(cardioProvider) == null
                    ? null
                    : () => context.push('/workout/cardio'),
                icon: const Icon(LucideIcons.heartPulse, size: 18),
                label: Text(
                  ref.watch(cardioProvider) != null
                      ? 'Продолжить кардио'
                      : cardioDone
                      ? 'Кардио сегодня уже было'
                      : 'Кардио',
                ),
              ),
              const SizedBox(height: 8),
              _JointButton(),
            ],
          ],
        ),
      ),
    );
  }
}

/// День отдыха по графику: когда следующая силовая и что можно сделать сегодня.
/// Сделанное — с галочкой, а не выключенной кнопкой.
class _RestDayCard extends ConsumerWidget {
  const _RestDayCard({
    required this.next,
    required this.recoveryDay,
    required this.cardioDone,
    required this.cardioActive,
  });

  /// Название следующей силовой по плану («Верх», «Всё тело А»).
  final String next;
  final bool recoveryDay;
  final bool cardioDone;
  final bool cardioActive;

  static const _days = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    final now = DateTime.now();
    // Ближайший день загрузки после сегодня.
    DateTime? nextDay;
    for (var i = 1; i <= 7 && hero != null; i++) {
      final d = now.add(Duration(days: i));
      if (hero.isLoadDay(d)) {
        nextDay = d;
        break;
      }
    }
    final when = nextDay == null
        ? null
        : nextDay.difference(DateTime(now.year, now.month, now.day)).inDays == 1
        ? 'завтра'
        : _days[nextDay.weekday - 1];
    final aura = ref.watch(auraProvider).value;
    final auraKind = aura?.equipped;
    final auraOpen = auraKind != null && (aura?.canTrain ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.moon, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recoveryDay ? 'День восстановления' : 'День отдыха',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Мышцы растут, пока ты восстанавливаешься. Серия не сгорит',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                if (when != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.dumbbell,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'Следующая силовая — ',
                            children: [
                              TextSpan(
                                text: '$when · $next',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Что можно сегодня',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (recoveryDay)
                _RestOption(
                  icon: LucideIcons.leaf,
                  title: 'Восстановление',
                  subtitle: 'Растяжка, суставы, дыхание · 15 мин',
                  done: cardioDone,
                  onTap: () => context.push('/workout/recovery'),
                ),
              _RestOption(
                icon: LucideIcons.heartPulse,
                title: cardioActive ? 'Продолжить кардио' : 'Лёгкое кардио',
                subtitle: 'Прогулка, велосипед, плавание · 20–30 мин',
                done: cardioDone && !cardioActive,
                onTap: () => context.push('/workout/cardio'),
              ),
              if (auraKind != null)
                _RestOption(
                  icon: auraIcon(auraKind),
                  iconColor: auraKind.color,
                  title: 'Тренировка ауры «${auraKind.label}»',
                  subtitle: auraOpen
                      ? 'Короткие интервалы · ~8 мин'
                      : 'Сегодня уже была или лимит недели',
                  done: !auraOpen,
                  onTap: () => context.push('/duels/auras'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Строка «что можно сегодня»: иконка, что и сколько, стрелка или галочка.
class _RestOption extends StatelessWidget {
  const _RestOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.done = false,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool done;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: done ? null : onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: done
                ? AppColors.textMuted
                : iconColor ?? Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: done
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            done ? LucideIcons.circleCheck : LucideIcons.chevronRight,
            size: 18,
            color: done ? AppColors.success : AppColors.textMuted,
          ),
        ],
      ),
    ),
  );
}

/// Силовая на сегодня сделана: итог, что дальше и вход в статистику.
class _DoneToday extends StatelessWidget {
  const _DoneToday({required this.log, required this.next});

  final List<LoggedWorkout> log;
  final ProgramDay next;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final w = log.firstWhere((w) => w.kind == WorkoutKind.strength);
    final week = TrainingStats(log).weekly(DateTime.now(), weeks: 1).single;
    final facts = [
      ('Время', formatMinutes(w.duration)),
      ('Подходов', '${w.sets}'),
      ('Поднято', '${w.volume.round()} кг'),
      ('Опыт', '+${w.xp}'),
    ];
    return Align(
      alignment: Alignment.topCenter,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.circleCheck, color: accent, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Силовая на сегодня сделана',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Одна силовая в день — мышцам нужно восстановиться. '
                'Дальше по плану: ${next.title}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (label, value) in facts)
                    Expanded(
                      child: Column(
                        children: [
                          Text(value, style: figureStyle(size: 17)),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'За эту неделю: ${workoutsWord(week.workouts)}, поднято ${week.volume.round()} кг',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.push('/workout/stats'),
                  icon: const Icon(LucideIcons.chartColumn, size: 16),
                  label: const Text('Статистика и динамика'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Вход в совместную тренировку; если она идёт — с кем и до скольки.
class _JointButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joint = ref.watch(jointProvider).value;
    final accent = Theme.of(context).colorScheme.primary;
    final active = joint?.bonusActive ?? false;
    return OutlinedButton.icon(
      onPressed: () => context.push('/workout/joint'),
      icon: Icon(LucideIcons.users, size: 18, color: active ? accent : null),
      label: Text(
        active
            ? 'Вместе: +${(GameConfig.jointBonus * 100).round()}% до ${_hm(joint!.endsAt)}'
            : joint != null
            ? 'Тренировка вместе: ждём друзей'
            : 'Тренировка вместе',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ---------- Идёт тренировка ----------

class _ActiveWorkout extends ConsumerStatefulWidget {
  const _ActiveWorkout({required this.session});

  final WorkoutSession session;

  @override
  ConsumerState<_ActiveWorkout> createState() => _ActiveWorkoutState();
}

class _ActiveWorkoutState extends ConsumerState<_ActiveWorkout> {
  int _expanded = 0;
  DateTime? _restEndsAt;

  /// Сигнал конца отдыха — «пора делать подход» (п. 72).
  Timer? _restBell;

  @override
  void dispose() {
    _restBell?.cancel();
    super.dispose();
  }

  WorkoutNotifier get _workout => ref.read(workoutProvider.notifier);

  @override
  void initState() {
    super.initState();
    ref.read(heartRateProvider.notifier).reconnectSaved();
  }

  Duration? get _restLeft {
    final ends = _restEndsAt;
    if (ends == null) return null;
    final left = ends.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  /// Конец отдыха, а пульс ещё высокий — подсказать подождать.
  String? _restHint(Duration left) {
    final hero = ref.read(heroProvider);
    if (hero == null) return null;
    final session = widget.session;
    // Скорость спада пульса — по отдыху между подходами этой тренировки.
    final tau = SetEffortAnalysis.recoveryTauOf(
      ref
          .read(heartRateProvider.notifier)
          .samplesBetween(session.startedAt, DateTime.now()),
      [
        for (final e in session.entries)
          for (final s in e.sets)
            if (s.at != null) s.at!,
      ],
      restingHr: hero.restingHeartRate,
    );
    return SetEffortAnalysis.restHint(
      bpm: ref.read(heartRateProvider).bpm,
      left: left,
      restingHr: hero.restingHeartRate,
      maxHr: hero.maxHeartRate,
      tau: tau,
    );
  }

  /// Облако подхода: вес и повторы, отдых перед ним и пульс, если был датчик.
  void _showSetInfo(BuildContext anchor, int entryIndex, int setIndex) {
    final session = widget.session;
    final entry = session.entries[entryIndex];
    final set = entry.sets[setIndex];
    final pulse = ref
        .read(heartRateProvider.notifier)
        .samplesBetween(session.startedAt, DateTime.now());
    SetPulse? info;
    for (final (id, i, p) in setPulses(
      startedAt: session.startedAt,
      entries: session.entries,
      pulse: pulse,
    )) {
      if (id == entry.exercise.id && i == setIndex) info = p;
    }
    final volume = entry.exercise.usesWeight
        ? ' · объём ${(set.weight * set.reps).round()} кг'
        : '';
    final rest = info?.rest;
    final peak = info?.peak;
    final base = info?.base;
    showInfoBubble(
      anchor,
      title: 'Подход ${setIndex + 1}: ${formatSet(entry.exercise, set)}',
      text: [
        if (info != null)
          'Записан на ${formatClock(Duration(seconds: info.t))} тренировки$volume',
        if (rest != null)
          'Отдых перед ним: ${formatClock(Duration(seconds: rest))}',
        if (peak != null)
          'Пульс: пик $peak${base == null ? '' : ', до подхода $base'} уд/мин'
        else
          'Пульса нет — с датчиком здесь будут пик и восстановление',
      ].join('\n'),
    );
  }

  /// «Не получается?» (п. 80): советы и замена прямо в тренировке.
  Future<void> _struggle(int index) async {
    final entry = widget.session.entries[index];
    final program = ref.read(programProvider);
    final options = swapOptions(
      entry.exercise,
      inWorkout: {for (final e in widget.session.entries) e.exercise.id},
      equipment: program.equipment,
      excluded: program.dislikedNow(DateTime.now()),
      female: ref.read(heroProvider)?.look.sex == AvatarSex.female,
    );
    // Учиться имеет смысл, только если это не подводящее к самому себе.
    final target = entry.plan?.skillFor == null
        ? entry.exercise
        : ExerciseCatalog.byId(entry.plan!.skillFor!);
    final choice = await showStruggleSheet(
      context,
      exercise: entry.exercise,
      options: options,
      hasSets: entry.sets.isNotEmpty,
      drills: target.id == entry.exercise.id
          ? SkillPractice.drillsFor(target, equipment: program.equipment)
          : const [],
    );
    if (choice == null || !mounted) return;
    final programNotifier = ref.read(programProvider.notifier);
    _workout.swapExercise(index, choice.to);
    setState(() => _expanded = entry.sets.isEmpty ? index : index + 1);
    if (choice.dislike && !program.disliked.containsKey(entry.exercise.id)) {
      await programNotifier.toggleDislike(entry.exercise.id);
    }
    if (choice.learn) await programNotifier.learnSkill(entry.exercise.id);
  }

  Future<void> _addExercise() async {
    final hero = ref.read(heroProvider);
    final exercise = await showExercisePicker(
      context,
      initialPart: hero?.lagging.firstOrNull,
      alreadyAdded: {for (final e in widget.session.entries) e.exercise.id},
    );
    if (exercise == null) return;
    _workout.addExercise(exercise);
    setState(() => _expanded = widget.session.entries.length);
  }

  /// Перед записью — проверка правдоподобия (п. 75): невозможное не засчитываем,
  /// резкий скачок к рекорду переспрашиваем.
  Future<void> _checkAndLog(int index, SetRecord set) async {
    final exercise = widget.session.entries[index].exercise;
    final best = ref.read(recordsProvider).best[exercise.id];
    final sanity = checkSet(
      exercise,
      set,
      best: best == null
          ? null
          : SetRecord(weight: best.weight, reps: best.reps),
    );
    if (sanity == SetSanity.ok) return _logSet(index, set);
    final rng = Random();
    final absurd = sanity == SetSanity.absurd;
    final record = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(absurd ? 'Не засчитано' : 'Это точно?'),
        content: Text(absurd ? absurdJoke(rng) : jumpJoke(rng)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Исправлю'),
          ),
          if (!absurd)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Да, это рекорд'),
            ),
        ],
      ),
    );
    if (record == true && mounted) _logSet(index, set);
  }

  /// Отдых между подходами — свой из настроек или по главной цели (п. 107, 117).
  Duration get _rest => restOf(ref);

  /// Весь текущий отдых (с добавками «+30 с») — для полоски на плашке.
  Duration _restTotal = const Duration(seconds: 90);

  void _logSet(int index, SetRecord set) {
    final exercise = widget.session.entries[index].exercise;
    _workout.logSet(index, set);
    TrainingSound.rest();
    // Кардио (бёрпи, скалолаз…) — короткая передышка: пульс держится в рабочей
    // зоне, отдых подстраивается по ответам после тренировки (circuit_rest.dart).
    _startRest(
      isConditioning(exercise)
          ? Duration(
              seconds: ref.read(circuitRestProvider.notifier).current().seconds,
            )
          : _rest,
    );
  }

  /// Запустить (или продлить) отдых: плашка, звонок в конце, метка в журнал.
  void _startRest(Duration total, {DateTime? from}) {
    final start = from ?? DateTime.now();
    setState(() {
      _restTotal = total;
      _restEndsAt = start.add(total);
    });
    _restBell?.cancel();
    _restBell = Timer(_restEndsAt!.difference(DateTime.now()), () {
      if (!mounted) return;
      TrainingSound.start();
      _workout.mark(WorkoutEventKind.restEnd);
    });
  }

  /// «+30 с»: продлить идущий отдых.
  void _moreRest() {
    final ends = _restEndsAt;
    if (ends == null) return;
    _startRest(
      _restTotal + const Duration(seconds: 30),
      from: ends.subtract(_restTotal),
    );
  }

  /// Ответил «был запас?» — переходим к следующему упражнению плана.
  void _answerReserve(int index, bool hadReserve) {
    _workout.setReserve(index, hadReserve);
    if (index + 1 >= widget.session.entries.length) return;
    setState(() => _expanded = index + 1);
  }

  Future<void> _finish() async {
    // «Завершить» стоит рядом с «Упражнение» — промахнуться легко, а
    // завершённую тренировку не вернуть: подтверждение, кнопка — через 3 с.
    final sure = await confirmWithDelay(
      context,
      title: 'Завершить тренировку?',
      message: 'Подходы сохранятся, добавить упражнения после этого нельзя',
      confirm: 'Завершить',
    );
    if (!sure || !mounted) return;
    final summary = await _workout.finish();
    if (summary != null && mounted) context.go('/workout/result');
  }

  Future<void> _confirmCancel() async {
    final cancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Отменить тренировку'),
        content: const Text('Записанные подходы не сохранятся'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Продолжить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
    if (cancel == true) _workout.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final program = ref.watch(programProvider);
    final warmupRows = session.warmup.isEmpty ? 0 : 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировка'),
        actions: [
          const _PulseIndicator(),
          const SizedBox(width: 16),
          // Тикают только часы, а не весь экран с карточками упражнений.
          EverySecond(
            builder: (_) => Text(
              formatClock(DateTime.now().difference(session.startedAt)),
              style: figureStyle(size: 15),
            ),
          ),
          IconButton(
            tooltip: 'Отменить тренировку',
            onPressed: _confirmCancel,
            icon: const Icon(
              LucideIcons.x,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          EverySecond(
            builder: (_) {
              final left = _restLeft;
              return left == null
                  ? const SizedBox.shrink()
                  : _RestBanner(
                      left: left,
                      total: _restTotal,
                      onMore: _moreRest,
                      onSkip: () {
                        _restBell?.cancel();
                        _workout.mark(WorkoutEventKind.restSkip);
                        setState(() => _restEndsAt = null);
                      },
                      hint: _restHint(left),
                    );
            },
          ),
          Expanded(
            child: session.entries.isEmpty && session.warmup.isEmpty
                ? const _EmptyHint()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    // Последняя строка — «+ Добавить упражнение»: второй вход на случай,
                    // если нижнюю панель на телефоне что-то перекрывает (п. 136).
                    itemCount: session.entries.length + warmupRows + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, row) {
                      if (row == session.entries.length + warmupRows) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addExercise,
                            icon: const Icon(LucideIcons.plus, size: 18),
                            label: const Text('Добавить упражнение'),
                          ),
                        );
                      }
                      if (row < warmupRows) {
                        return WarmupCard(
                          moveIds: session.warmup,
                          done: session.warmupDone,
                          onToggle: _workout.toggleWarmup,
                        );
                      }
                      final i = row - warmupRows;
                      return _ExerciseCard(
                        entry: session.entries[i],
                        progress: program.progressOf(
                          session.entries[i].exercise.id,
                        ),
                        onReserve: (reserve) => _answerReserve(i, reserve),
                        expanded: i == _expanded,
                        onExpand: () {
                          _workout.mark(
                            WorkoutEventKind.exerciseOpen,
                            exerciseId: session.entries[i].exercise.id,
                          );
                          setState(() => _expanded = i);
                        },
                        onLog: (set) => _checkAndLog(i, set),
                        onUndo: () => _workout.undoLastSet(i),
                        onRemove: () => _workout.removeExercise(i),
                        onStruggle: () => _struggle(i),
                        onSetInfo: (c, set) => _showSetInfo(c, i, set),
                        toFailure: toFailureFor(
                          trainingLevelOf(
                            ref.watch(heroProvider),
                            ref.watch(programProvider),
                          ),
                          session.entries[i].exercise,
                        ),
                      );
                    },
                  ),
          ),
          _BottomActions(
            canFinish: session.totalSets > 0,
            onAdd: _addExercise,
            onFinish: _finish,
          ),
        ],
      ),
    );
  }
}

/// Живой пульс в шапке. Без датчика — ссылка на подключение.
class _PulseIndicator extends ConsumerWidget {
  const _PulseIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulse = ref.watch(heartRateProvider);
    if (!pulse.isConnected) {
      return IconButton(
        tooltip: 'Подключить датчик пульса',
        onPressed: () => context.push('/profile/heart-rate'),
        icon: const Icon(
          LucideIcons.heartOff,
          size: 18,
          color: AppColors.textMuted,
        ),
      );
    }
    return Tappable(
      semantics: 'Пульс ${pulse.bpm ?? 'нет данных'}',
      onTap: (c) => _showPulseInfo(c, ref),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              Icon(
                LucideIcons.heart,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(pulse.bpm?.toString() ?? '—', style: figureStyle(size: 15)),
            ],
          ),
        ),
      ),
    );
  }

  /// Облако пульса (п. 127): зона сейчас, средний и максимум за тренировку.
  void _showPulseInfo(BuildContext anchor, WidgetRef ref) {
    final bpm = ref.read(heartRateProvider).bpm;
    final max = ref.read(heroProvider)?.maxHeartRate ?? 190;
    final started = ref.read(workoutProvider)?.startedAt;
    final samples = started == null
        ? const <PulseSample>[]
        : ref
              .read(heartRateProvider.notifier)
              .samplesBetween(started, DateTime.now());
    final pct = bpm == null ? null : (bpm * 100 / max).round();
    final zone = switch (pct) {
      null => 'нет данных',
      < 60 => 'лёгкая',
      < 70 => 'разминка',
      < 80 => 'аэробная — выносливость',
      < 90 => 'тяжёлая — сила и скорость',
      _ => 'максимальная — ненадолго',
    };
    final avg = samples.isEmpty
        ? null
        : (samples.fold<int>(0, (a, s) => a + s.bpm) / samples.length).round();
    final top = samples.isEmpty
        ? null
        : samples.map((s) => s.bpm).reduce((a, b) => a > b ? a : b);
    showInfoBubble(
      anchor,
      title: 'Пульс ${bpm ?? '—'}${pct == null ? '' : ' · $pct% от максимума'}',
      text: [
        'Зона: $zone',
        if (avg != null) 'За тренировку: средний $avg, максимум $top',
        'Твой максимум — около $max уд/мин. Пульс подтверждает тренировку '
            'и подсказывает, когда отдых закончен.',
      ].join('\n'),
      actionLabel: 'Датчики',
      onAction: () => GoRouter.of(anchor).push('/profile/heart-rate'),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text(
        'Добавь первое упражнение. Если какая-то часть тела отстаёт, список откроется на ней',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}

class _RestBanner extends StatelessWidget {
  const _RestBanner({
    required this.left,
    required this.onSkip,
    this.hint,
    this.total = const Duration(seconds: 90),
    this.onMore,
  });

  /// «+30 с» к отдыху.
  final VoidCallback? onMore;

  /// Весь отдых — для полоски прогресса.
  final Duration total;

  final Duration left;
  final VoidCallback onSkip;

  /// «Пульс ещё высокий — отдохни ещё 30 с».
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final total = this.total.inSeconds;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.timer,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Отдых',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Text(
                formatClock(left),
                style: figureStyle(size: 15, color: accent),
              ),
              const Spacer(),
              if (onMore != null)
                TextButton(onPressed: onMore, child: const Text('+30 с')),
              TextButton(onPressed: onSkip, child: const Text('Пропустить')),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.heartPulse,
                    size: 14,
                    color: Color(0xFFFF6B5E),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hint!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: left.inSeconds / total,
              minHeight: 4,
              color: accent,
              backgroundColor: AppColors.raised,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.canFinish,
    required this.onAdd,
    required this.onFinish,
  });

  final bool canFinish;
  final VoidCallback onAdd;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: AppColors.hairline),
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onAdd,
              icon: const Icon(LucideIcons.plus, size: 18),
              // Крупный шрифт и узкий экран: подпись ужимается, а не переносится
              // по буквам и не выталкивает кнопку за край.
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Упражнение', maxLines: 1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: canFinish ? onFinish : null,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Завершить', maxLines: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Карточка упражнения ----------

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.entry,
    required this.progress,
    required this.onReserve,
    required this.expanded,
    required this.onExpand,
    required this.onLog,
    required this.onUndo,
    required this.onRemove,
    this.onStruggle,
    this.toFailure = false,
    this.onSetInfo,
  });

  /// «Не получается?» — советы и замена (п. 80).
  final VoidCallback? onStruggle;

  /// Нажатие на записанный подход — облако с пульсом и отдыхом (п. 127).
  final void Function(BuildContext context, int setIndex)? onSetInfo;

  final ExerciseEntry entry;

  /// Опытному: последний подход — до отказа (п. 73).
  final bool toFailure;
  final ExerciseProgress progress;
  final ValueChanged<bool> onReserve;
  final bool expanded;
  final VoidCallback onExpand;
  final ValueChanged<SetRecord> onLog;
  final VoidCallback onUndo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final exercise = entry.exercise;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardHeader(
              entry: entry,
              onTap: onExpand,
              onRemove: entry.sets.isEmpty ? onRemove : null,
            ),
            if (entry.plan != null)
              _PlanTarget(plan: entry.plan!, progress: progress),
            if (toFailure && !entry.isFull) const _ToFailureNote(),
            for (final (i, set) in entry.sets.indexed)
              Tappable(
                onTap: (c) => onSetInfo?.call(c, i),
                child: _SetRow(index: i + 1, text: formatSet(exercise, set)),
              ),
            if (entry.planDone)
              _ReserveQuestion(answer: entry.hadReserve, onAnswer: onReserve),
            // Свёрнутое и недоделанное — видно, что сюда можно вернуться (подходов не 4/4).
            if (!expanded && !entry.isFull)
              _AddSetHint(onTap: onExpand, more: entry.planDone),
            if (expanded)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: entry.isFull
                    ? Text(
                        'Не больше ${GameConfig.maxSetsPerExercise} подходов в упражнении',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      )
                    : _SetComposer(
                        key: ValueKey(exercise.id),
                        exercise: exercise,
                        previous: entry.sets.lastOrNull ?? _plannedSet(entry),
                        canUndo: entry.sets.isNotEmpty,
                        onLog: onLog,
                        onUndo: onUndo,
                      ),
              ),
            if (expanded && !entry.isFull && onStruggle != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onStruggle,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.lifeBuoy, size: 15),
                  label: const Text(
                    'Не получается?',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension on _ExerciseCard {
  /// Первый подход по плану: рабочий вес и верх диапазона повторов.
  SetRecord? _plannedSet(ExerciseEntry entry) {
    final plan = entry.plan;
    if (plan == null) return null;
    return SetRecord(
      weight: plan.suggestedWeight(progress),
      reps: DoubleProgression.repsRange(plan, progress).max,
    );
  }
}

/// Свёрнутая карточка, где ещё можно сделать подход: «+ Нажми, чтобы добавить подход».
class _AddSetHint extends StatelessWidget {
  const _AddSetHint({required this.onTap, required this.more});

  final VoidCallback onTap;

  /// План уже выполнен — подход сверх плана, подсказка спокойнее.
  final bool more;

  @override
  Widget build(BuildContext context) {
    // Спокойный вторичный цвет: акцентом это читалось как ошибка.
    final color = more ? AppColors.textMuted : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 12, 2),
        child: Row(
          children: [
            Icon(LucideIcons.circlePlus, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                more ? 'Добавить ещё подход' : 'Добавить подход',
                style: TextStyle(fontSize: 13, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Пометка «последний подход — до отказа» с пояснением по нажатию.
class _ToFailureNote extends StatelessWidget {
  const _ToFailureNote();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(toFailureTitle),
          content: const SingleChildScrollView(child: Text(toFailureText)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(LucideIcons.flame, size: 16, color: accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Последний подход — до отказа',
                style: TextStyle(fontSize: 13, color: accent),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(LucideIcons.info, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _PlanTarget extends StatelessWidget {
  const _PlanTarget({required this.plan, required this.progress});

  final PlannedExercise plan;
  final ExerciseProgress progress;

  @override
  Widget build(BuildContext context) {
    final range = DoubleProgression.repsRange(plan, progress);
    final unit = plan.exercise.unit == ExerciseUnit.seconds ? ' с' : '';
    final calibrating = plan.exercise.usesWeight && progress.isCalibrating;
    return Tappable(
      onTap: (c) => showInfoBubble(
        c,
        title: 'Подходы и запас',
        text:
            '${plan.sets} × ${range.min}–${range.max}$unit. «${plan.repsInReserve} в запасе» — '
            'остановись, когда можешь сделать ещё ${plan.repsInReserve}: так сила растёт '
            'без травм. Если во всех подходах получился верх диапазона с запасом, в '
            'следующий раз вес будет чуть больше.',
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6, right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Цель: ${plan.sets} × ${range.min}–${range.max}$unit · ${plan.repsInReserve} в запасе',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (calibrating)
              Text(
                'Подбери вес: ${range.max} повторов и ещё ${plan.repsInReserve} в запасе',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// После запланированных подходов: от ответа зависит, растёт ли вес.
class _ReserveQuestion extends StatelessWidget {
  const _ReserveQuestion({required this.answer, required this.onAnswer});

  final bool? answer;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Был запас?',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          ChoiceChip(
            label: const Text('Да'),
            selected: answer == true,
            showCheckmark: false,
            onSelected: (_) => onAnswer(true),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Впритык'),
            selected: answer == false,
            showCheckmark: false,
            onSelected: (_) => onAnswer(false),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  final ExerciseEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final exercise = entry.exercise;
    final parts = exercise.shares.keys
        .map((p) => p.label.toLowerCase())
        .join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      // Длинное название переносится на вторую строку — строка растёт, а не обрезается.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: exercise.mainPart.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      parts,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${entry.sets.length}/${GameConfig.maxSetsPerExercise}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Убрать упражнение',
                  onPressed: onRemove,
                  icon: const Icon(
                    LucideIcons.x,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28,
    child: Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '$index',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// Ввод следующего подхода: вес и повторы кнопками «−» и «+».
class _SetComposer extends StatefulWidget {
  const _SetComposer({
    super.key,
    required this.exercise,
    required this.previous,
    required this.canUndo,
    required this.onLog,
    required this.onUndo,
  });

  final Exercise exercise;
  final SetRecord? previous;
  final bool canUndo;
  final ValueChanged<SetRecord> onLog;
  final VoidCallback onUndo;

  @override
  State<_SetComposer> createState() => _SetComposerState();
}

class _SetComposerState extends State<_SetComposer> {
  late double _weight =
      widget.previous?.weight ?? widget.exercise.defaultWeight;
  late int _reps = widget.previous?.reps ?? widget.exercise.defaultReps;

  double get _weightStep => widget.exercise.defaultWeight >= 20 ? 2.5 : 1;
  int get _repsStep => widget.exercise.unit == ExerciseUnit.seconds ? 5 : 1;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (exercise.usesWeight) ...[
              Expanded(
                child: _Stepper(
                  label: 'кг',
                  value: formatWeight(_weight),
                  onMinus: _weight > 0
                      ? () => setState(
                          () => _weight = (_weight - _weightStep).clamp(0, 500),
                        )
                      : null,
                  onPlus: () => setState(() => _weight += _weightStep),
                  onEdit: () async {
                    final v = await _askNumber(
                      context,
                      title: 'Вес, кг',
                      initial: _weight,
                      decimal: true,
                      max: 500,
                    );
                    if (v != null) setState(() => _weight = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _Stepper(
                label: exercise.unit == ExerciseUnit.seconds ? 'сек' : 'повт.',
                value: '$_reps',
                onMinus: _reps > _repsStep
                    ? () => setState(() => _reps -= _repsStep)
                    : null,
                onPlus: () => setState(() => _reps += _repsStep),
                onEdit: () async {
                  final v = await _askNumber(
                    context,
                    title: exercise.unit == ExerciseUnit.seconds
                        ? 'Секунды'
                        : 'Повторы',
                    initial: _reps.toDouble(),
                    decimal: false,
                    max: 999,
                  );
                  if (v != null && v >= 1) setState(() => _reps = v.round());
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (widget.canUndo)
              IconButton(
                tooltip: 'Удалить последний подход',
                onPressed: widget.onUndo,
                icon: const Icon(
                  LucideIcons.undo2,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            Expanded(
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: AppColors.raised,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => widget.onLog(
                  SetRecord(
                    weight: exercise.usesWeight ? _weight : 0,
                    reps: _reps,
                  ),
                ),
                child: const Text('Записать подход'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  /// Нажатие на число — ввод с клавиатуры.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    // Высота растёт с системным шрифтом, «−» и «+» компактные — на узком
    // экране с крупным шрифтом «+» не уезжает за край (п. 136).
    const tight = BoxConstraints(minWidth: 40, minHeight: 40);
    return Container(
      constraints: BoxConstraints(
        minHeight: MediaQuery.textScalerOf(context).scale(48).clamp(48, 72),
      ),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Меньше',
            constraints: tight,
            padding: EdgeInsets.zero,
            onPressed: onMinus,
            icon: const Icon(LucideIcons.minus, size: 18),
          ),
          Expanded(
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: figureStyle(size: 16)),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Больше',
            constraints: tight,
            padding: EdgeInsets.zero,
            onPressed: onPlus,
            icon: const Icon(LucideIcons.plus, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Число с клавиатуры: вес (с запятой, до 0,5 кг) или повторы. null — отмена или ошибка.
Future<double?> _askNumber(
  BuildContext context, {
  required String title,
  required double initial,
  required bool decimal,
  required double max,
}) {
  final field = TextEditingController(
    text: decimal ? formatWeight(initial) : '${initial.round()}',
  );
  field.selection = TextSelection(
    baseOffset: 0,
    extentOffset: field.text.length,
  );
  double? parse() {
    final v = double.tryParse(field.text.trim().replaceAll(',', '.'));
    if (v == null || v < 0 || v > max) return null;
    return decimal ? (v * 2).round() / 2 : v.roundToDouble();
  }

  return showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: field,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        textInputAction: TextInputAction.done,
        style: figureStyle(size: 22),
        onSubmitted: (_) => Navigator.pop(context, parse()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, parse()),
          child: const Text('Готово'),
        ),
      ],
    ),
  );
}
