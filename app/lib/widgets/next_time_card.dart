import 'package:flutter/material.dart';

import '../game/exercise_catalog.dart';
import '../game/program.dart';
import '../state/program_state.dart';
import '../theme.dart';
import 'format.dart';

/// Итог по программе: веса на следующий раз и бонус за тренировку по плану.
class NextTimeCard extends StatelessWidget {
  const NextTimeCard({super.key, required this.result});

  final PlanResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'В следующий раз',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            for (final change in result.changes) _ChangeRow(change: change),
            if (result.bonusCoins > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Тренировка по плану: +${result.bonusCoins} монет',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final ProgressChange change;

  String get _target {
    final plan = change.plan;
    final range = DoubleProgression.repsRange(plan, change.after);
    final unit = plan.exercise.unit == ExerciseUnit.seconds ? ' с' : '';
    final reps = '${range.min}–${range.max}$unit';
    final weight = change.after.workingWeight;
    return weight == null ? reps : '${formatWeight(weight)} кг × $reps';
  }

  String? get _note => switch (change.kind) {
    ProgressKind.increase => 'прибавка',
    ProgressKind.calibrated => 'рабочий вес',
    ProgressKind.deload => 'откат на 10%, это нормально',
    ProgressKind.hold => null,
  };

  @override
  Widget build(BuildContext context) {
    final note = _note;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              change.plan.exercise.name,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _target,
                style: const TextStyle(
                  fontSize: 14,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 12,
                    color: change.kind == ProgressKind.increase
                        ? Theme.of(context).colorScheme.primary
                        : AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
