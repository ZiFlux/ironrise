import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/exercise_catalog.dart';
import '../game/set_effort.dart';
import '../theme.dart';
import 'format.dart';

/// Итог «Пульс по подходам»: насколько тяжёлым был каждый подход,
/// какие упражнения поднимают пульс сильнее и где пульс не отреагировал.
class SetEffortCard extends StatelessWidget {
  const SetEffortCard({super.key, required this.analysis});

  final SetEffortAnalysis analysis;

  /// Хвост прошлого подхода к началу этого, уд/мин, — подход начат неостывшим.
  static const carryWarning = 75;

  static const _levelColors = {
    EffortLevel.light: Color(0xFF4CC38A),
    EffortLevel.moderate: Color(0xFFFFB547),
    EffortLevel.hard: Color(0xFFFF6B5E),
  };

  @override
  Widget build(BuildContext context) {
    final byExercise = analysis.riseByExercise;
    final flat = analysis.flatSets;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  LucideIcons.heartPulse,
                  size: 18,
                  color: Color(0xFFFF6B5E),
                ),
                SizedBox(width: 8),
                Text(
                  'Пульс по подходам',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final entry in byExercise.entries) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ExerciseCatalog.tryById(entry.key)?.name ?? entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  // Подход — точка цвета тяжести, по порядку.
                  for (final s in analysis.sets.where(
                    (s) => s.exerciseId == entry.key,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Tooltip(
                        message:
                            'Подход ${s.setIndex + 1}: пик ${s.peak}, '
                            '+${s.rise} — ${s.level.label}',
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s.flat
                                ? AppColors.raised
                                : _levelColors[s.level],
                            border: s.flat
                                ? Border.all(color: AppColors.textMuted)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '+${entry.value}',
                      textAlign: TextAlign.right,
                      style: figureStyle(
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 12,
              children: [
                for (final l in EffortLevel.values)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _levelColors[l],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Справа — средний подъём пульса за подход, уд/мин',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'После подхода пульс приходит в норму примерно за '
              '${formatClock(analysis.recoveryTau * 3)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (analysis
                .carriedSets(SetEffortCard.carryWarning)
                .isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Подходов, начатых с неостывшим пульсом: '
                '${analysis.carriedSets(SetEffortCard.carryWarning).length}. '
                'Подъём пульса в них посчитан от спадающего хвоста прошлого подхода',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (flat.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Подходов без подъёма пульса: ${flat.length}. Если датчик сидел '
                'плотно, возможно, вес можно прибавить',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
