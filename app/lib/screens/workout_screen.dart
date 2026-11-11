import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/exercise_catalog.dart';
import '../game/program.dart';
import '../game/recommendation.dart';
import '../game/game_config.dart';
import '../game/workout.dart';
import '../state/cardio_state.dart';
import '../state/heart_rate_state.dart';
import '../state/program_state.dart';
import '../state/providers.dart';
import '../state/workout_state.dart';
import '../theme.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/format.dart';

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

class _StartView extends ConsumerWidget {
  const _StartView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = Recommendation.forLagging(
      ref.watch(heroProvider)?.lagging ?? const [],
    );
    final adapted = ref.watch(programProvider).adaptedToday(DateTime.now());
    final today = adapted.day;
    final hint = [
      [for (final e in today.exercises) e.exercise.name].join(' · '),
      if (adapted.eased) 'План облегчён: на подход меньше',
      if (adapted.adjustments.isNotEmpty) 'Часть упражнений заменена, пока бережём больное место',
    ].join('\n');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировка'),
        actions: [
          IconButton(
            tooltip: 'Справочник упражнений',
            onPressed: () => context.go('/workout/exercises'),
            icon: const Icon(LucideIcons.bookOpen, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          children: [
            const Spacer(),
            const Icon(
              LucideIcons.dumbbell,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Сегодня: ${today.title}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => ref.read(workoutProvider.notifier).startPlanned(today),
              child: Text(planLabel(today)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                final notifier = ref.read(workoutProvider.notifier)..start();
                final exercise = rec?.exercise;
                if (exercise != null) notifier.addExercise(exercise);
              },
              child: const Text('Без плана'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/workout/cardio'),
              icon: const Icon(LucideIcons.heartPulse, size: 18),
              label: Text(
                ref.watch(cardioProvider) == null
                    ? 'Кардио'
                    : 'Продолжить кардио',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Идёт тренировка ----------

class _ActiveWorkout extends ConsumerStatefulWidget {
  const _ActiveWorkout({required this.session});

  final WorkoutSession session;

  @override
  ConsumerState<_ActiveWorkout> createState() => _ActiveWorkoutState();
}

class _ActiveWorkoutState extends ConsumerState<_ActiveWorkout> {
  late final Timer _ticker;
  int _expanded = 0;
  DateTime? _restEndsAt;

  WorkoutNotifier get _workout => ref.read(workoutProvider.notifier);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
    ref.read(heartRateProvider.notifier).reconnectSaved();
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Duration? get _restLeft {
    final ends = _restEndsAt;
    if (ends == null) return null;
    final left = ends.difference(DateTime.now());
    return left.isNegative ? null : left;
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
    if (index + 1 < widget.session.entries.length) setState(() => _expanded = index + 1);
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
    final elapsed = DateTime.now().difference(session.startedAt);
    final restLeft = _restLeft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренировка'),
        actions: [
          const _PulseIndicator(),
          const SizedBox(width: 16),
          Text(formatClock(elapsed), style: figureStyle(size: 15)),
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
          if (restLeft != null)
            _RestBanner(
              left: restLeft,
              onSkip: () => setState(() => _restEndsAt = null),
            ),
          Expanded(
            child: session.entries.isEmpty
                ? const _EmptyHint()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    itemCount: session.entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ExerciseCard(
                      entry: session.entries[i],
                      progress: program.progressOf(session.entries[i].exercise.id),
                      onReserve: (reserve) => _answerReserve(i, reserve),
                      expanded: i == _expanded,
                      onExpand: () => setState(() => _expanded = i),
                      onLog: (set) => _logSet(i, set),
                      onUndo: () => _workout.undoLastSet(i),
                      onRemove: () => _workout.removeExercise(i),
                    ),
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
  const _RestBanner({required this.left, required this.onSkip});

  final Duration left;
  final VoidCallback onSkip;

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
            if (entry.plan != null) _PlanTarget(plan: entry.plan!, progress: progress),
            for (final (i, set) in entry.sets.indexed)
              _SetRow(index: i + 1, text: formatSet(exercise, set)),
            if (entry.planDone)
              _ReserveQuestion(answer: entry.hadReserve, onAnswer: onReserve),
            if (expanded)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: entry.isFull
                    ? Text(
                        'Максимум ${GameConfig.maxSetsPerExercise} подходов на упражнение',
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
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
            child: Text('Был запас?', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
      child: SizedBox(
        height: 52,
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
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
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
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

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
