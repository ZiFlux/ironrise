import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/exercise_catalog.dart';
import '../game/program.dart';
import '../game/recommendation.dart';
import '../game/training_stats.dart';
import '../game/game_config.dart';
import '../game/set_effort.dart';
import '../game/warmup.dart';
import '../game/wellbeing.dart';
import '../game/workout.dart';
import '../state/hero.dart';
import '../game/training_format.dart';
import '../state/cardio_state.dart';
import '../state/heart_rate_state.dart';
import '../state/program_state.dart';
import '../state/joint_state.dart';
import '../state/providers.dart';
import '../state/workout_state.dart';
import '../state/training_log.dart';
import '../theme.dart';
import '../widgets/every_second.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/format.dart';
import '../widgets/warmup_card.dart';

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

String _phaseLine(UserProgram program) => switch (program.phase) {
  ProgramPhase.start =>
    'Фаза «Старт» · ${program.completedWorkouts} из ${ProgramPhase.startWorkouts} тренировок',
  ProgramPhase.base => 'Фаза «База»: 3 подхода и упражнение на отстающую часть',
};

/// Сплит: какой день недели что тренировать — «Пн спина и бицепс · Ср грудь…».
String? _splitLine(UserProgram program, HeroProfile? hero) {
  if (hero?.format != TrainingFormat.split ||
      program.phase != ProgramPhase.base) {
    return null;
  }
  final layout = weekLayout(
    days: program.days(hero!.trainingDays.length, split: true),
    nextIndex: program.nextDayIndex,
    trainingDays: hero.trainingDays,
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
    final notes = [
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
          IconButton(
            tooltip: 'Статистика',
            onPressed: () => context.go('/workout/stats'),
            icon: const Icon(LucideIcons.chartColumn, size: 20),
          ),
          IconButton(
            tooltip: 'База знаний',
            onPressed: () => context.go('/workout/exercises'),
            icon: const Icon(LucideIcons.bookOpen, size: 20),
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
              child: strengthDone
                  ? _DoneToday(log: log, next: today)
                  : Align(
                      alignment: Alignment.topCenter,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Text(
                                'Сегодня · ${today.title}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Text(
                                [
                                  _phaseLine(program),
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
                                        child: Text(
                                          e.exercise.name,
                                          style: const TextStyle(fontSize: 15),
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
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            if (!strengthDone) ...[
              FilledButton(
                onPressed: () =>
                    ref.read(workoutProvider.notifier).startPlanned(today),
                child: Text(planLabel(today)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  final notifier = ref.read(workoutProvider.notifier)..start();
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
                  : () => context.go('/workout/cardio'),
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
        ),
      ),
    );
  }
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
                'За эту неделю: ${week.workouts} трен., ${week.volume.round()} кг',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.go('/workout/stats'),
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
      onPressed: () => context.go('/workout/joint'),
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
    return SetEffortAnalysis.restHint(
      bpm: ref.read(heartRateProvider).bpm,
      left: left,
      restingHr: hero.restingHeartRate,
      maxHr: hero.maxHeartRate,
    );
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

  void _logSet(int index, SetRecord set) {
    _workout.logSet(index, set);
    setState(
      () => _restEndsAt = DateTime.now().add(GameConfig.restBetweenSets),
    );
  }

  /// Ответил «был запас?» — переходим к следующему упражнению плана.
  void _answerReserve(int index, bool hadReserve) {
    _workout.setReserve(index, hadReserve);
    if (index + 1 >= widget.session.entries.length) return;
    setState(() => _expanded = index + 1);
  }

  Future<void> _finish() async {
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
                      onSkip: () => setState(() => _restEndsAt = null),
                      hint: _restHint(left),
                    );
            },
          ),
          Expanded(
            child: session.entries.isEmpty && session.warmup.isEmpty
                ? const _EmptyHint()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    itemCount: session.entries.length + warmupRows,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, row) {
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
                        onExpand: () => setState(() => _expanded = i),
                        onLog: (set) => _logSet(i, set),
                        onUndo: () => _workout.undoLastSet(i),
                        onRemove: () => _workout.removeExercise(i),
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
        onPressed: () => context.go('/profile/heart-rate'),
        icon: const Icon(
          LucideIcons.heartOff,
          size: 18,
          color: AppColors.textMuted,
        ),
      );
    }
    return Semantics(
      label: 'Пульс ${pulse.bpm ?? 'нет данных'}',
      excludeSemantics: true,
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
  const _RestBanner({required this.left, required this.onSkip, this.hint});

  final Duration left;
  final VoidCallback onSkip;

  /// «Пульс ещё высокий — отдохни ещё 30 с».
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final total = GameConfig.restBetweenSets.inSeconds;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
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
              label: const Text('Упражнение'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: canFinish ? onFinish : null,
              child: const Text('Завершить'),
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
  });

  final ExerciseEntry entry;
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
            for (final (i, set) in entry.sets.indexed)
              _SetRow(index: i + 1, text: formatSet(exercise, set)),
            if (entry.planDone)
              _ReserveQuestion(answer: entry.hadReserve, onAnswer: onReserve),
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
      weight: progress.workingWeight ?? entry.exercise.defaultWeight,
      reps: DoubleProgression.repsRange(plan, progress).max,
    );
  }
}

/// «Цель: 2 × 10–12 · 3 в запасе» и подсказка при первом подборе веса.
class _PlanTarget extends StatelessWidget {
  const _PlanTarget({required this.plan, required this.progress});

  final PlannedExercise plan;
  final ExerciseProgress progress;

  @override
  Widget build(BuildContext context) {
    final range = DoubleProgression.repsRange(plan, progress);
    final unit = plan.exercise.unit == ExerciseUnit.seconds ? ' с' : '';
    final calibrating = plan.exercise.usesWeight && progress.isCalibrating;
    return Padding(
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
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
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
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Меньше',
            onPressed: onMinus,
            icon: const Icon(LucideIcons.minus, size: 18),
          ),
          Expanded(
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
          IconButton(
            tooltip: 'Больше',
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
