import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/exercise_catalog.dart';
import '../game/program.dart';
import '../game/skill_practice.dart';
import '../state/program_state.dart';
import '../state/workout_state.dart';
import '../theme.dart';

/// Подпись упражнения в плане, если оно — часть отработки.
String? skillNote(PlannedExercise e) {
  final target = e.skillFor == null
      ? null
      : ExerciseCatalog.tryById(e.skillFor!)?.name;
  return switch (e.skillRole) {
    null => null,
    SkillRole.alternative => 'Замена, пока учимся: $target',
    SkillRole.drill => 'Подводящее: учимся делать «$target»',
    SkillRole.check => 'Проверка: получается ли теперь',
  };
}

/// Упражнения, которые учимся делать: когда проверка и кнопка отдельного
/// комплекса (skill_practice.dart). Пусто — ничего не показывает.
class SkillGoalsPanel extends ConsumerWidget {
  const SkillGoalsPanel({super.key, this.canStart = true});

  /// Показать кнопку «Комплекс»: в день отдыха — да, в плане дня — нет
  /// (подводящие уже в тренировке, а силовая — одна в день).
  final bool canStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider);
    final goals = program.skillGoals.values.toList();
    if (goals.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final goal in goals)
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.graduationCap,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Учимся: ${goal.exercise.name}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        [
                          goal.checkDue(now)
                              ? 'проверка — в ближайшей тренировке с ним'
                              : 'проверка через ${goal.daysToCheck(now)} дн.',
                          if (goal.practicedOutside(now))
                            'комплекс делаешь отдельно — в плане только замена',
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canStart)
                  TextButton(
                    onPressed: canStart
                        ? () => ref
                              .read(workoutProvider.notifier)
                              .startPractice(
                                SkillPractice.complex(
                                  goal,
                                  equipment: program.equipment,
                                  excluded: program.dislikedNow(now),
                                ),
                              )
                        : null,
                    child: const Text('Комплекс'),
                  ),
                PopupMenuButton<void>(
                  icon: const Icon(
                    LucideIcons.ellipsisVertical,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: () => _showComplex(context, goal, program),
                      child: const Text('Что в комплексе'),
                    ),
                    PopupMenuItem(
                      onTap: () => ref
                          .read(programProvider.notifier)
                          .dropSkill(goal.exerciseId),
                      child: const Text('Больше не отрабатывать'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showComplex(BuildContext context, SkillGoal goal, UserProgram program) {
    final drills = SkillPractice.complex(
      goal,
      equipment: program.equipment,
      excluded: program.dislikedNow(DateTime.now()),
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Комплекс: ${goal.exercise.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in drills)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${d.exercise.name} — ${d.sets} × ${d.repsMin}–${d.repsMax}'
                  '${d.exercise.unit == ExerciseUnit.seconds ? ' с' : ''}',
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Делай отдельно от плана, хоть каждый день: тогда в тренировки '
              'пойдёт только замена. Через 2 недели упражнение вернётся в план '
              'на проверку.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
