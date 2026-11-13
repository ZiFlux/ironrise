import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/exercise_catalog.dart';
import '../game/muscles.dart';
import '../game/session_builder.dart';
import '../game/training_analysis.dart';
import '../theme.dart';

/// Блок «Анализ и прогноз» на экране статистики (п. 51 бэклога).
class TrainingAnalysisView extends StatelessWidget {
  const TrainingAnalysisView({
    super.key,
    required this.analysis,
    required this.plannedPerWeek,
  });

  final TrainingAnalysis analysis;
  final int plannedPerWeek;

  /// Крупные мышцы — на них норма важнее всего; мелкие работают в базе.
  static const _major = [
    Muscle.pecs,
    Muscle.lats,
    Muscle.delts,
    Muscle.biceps,
    Muscle.triceps,
    Muscle.quads,
    Muscle.hamstrings,
    Muscle.glutes,
    Muscle.abs,
  ];

  @override
  Widget build(BuildContext context) {
    final level = analysis.level;
    final sets = analysis.muscleSets();
    final insights = analysis.insights(plannedPerWeek: plannedPerWeek);
    final forecasts = analysis.forecasts();
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Уровень «${level.label}»: ${level.exercises} упражнений в тренировке, '
          'норма — ${level.weeklySets} подходов на мышцу в неделю',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        for (final m in _major)
          _CoverageRow(
            muscle: m,
            done: sets[m] ?? 0,
            target: weeklyTarget(m, level),
            accent: accent,
          ),
        if (insights.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final text in insights)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      LucideIcons.lightbulb,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(text, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        if (forecasts.isEmpty)
          const Text(
            'Прогноз появится после 3 тренировок с одним упражнением за 10+ дней',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          )
        else ...[
          const Text(
            'Прогноз, если продолжать так же',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          for (final f in forecasts) _ForecastRow(forecast: f, accent: accent),
        ],
      ],
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.muscle,
    required this.done,
    required this.target,
    required this.accent,
  });

  final Muscle muscle;
  final double done;
  final double target;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 1.0 : done / target;
    final color = ratio >= 1
        ? accent
        : ratio >= 0.6
        ? const Color(0xFFFFB547)
        : const Color(0xFFE5484D);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              muscle.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1),
                minHeight: 6,
                color: color,
                backgroundColor: AppColors.raised,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${done.round()}/${target.round()}',
              textAlign: TextAlign.right,
              style: figureStyle(size: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({required this.forecast, required this.accent});

  final LiftForecast forecast;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final e = ExerciseCatalog.byId(forecast.exerciseId);
    final unit = e.usesWeight
        ? 'кг'
        : e.unit == ExerciseUnit.seconds
        ? 'с'
        : 'повт.';
    String v(double x) => x.round().toString();
    final pct = forecast.weeklyPct * 100;
    final (icon, color, note) = switch (forecast.trend) {
      LiftTrend.growing => (
        LucideIcons.trendingUp,
        accent,
        '+${pct.toStringAsFixed(1)} % в нед.',
      ),
      LiftTrend.plateau => (
        LucideIcons.minus,
        const Color(0xFFFFB547),
        'на месте',
      ),
      LiftTrend.declining => (
        LucideIcons.trendingDown,
        const Color(0xFFE5484D),
        'снижается',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  forecast.trend == LiftTrend.growing
                      ? 'сейчас ${v(forecast.current)} → через 4 нед. ${v(forecast.in4Weeks)} → '
                            'через 12 нед. ${v(forecast.in12Weeks)} $unit'
                      : 'сейчас ${v(forecast.current)} $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(note, style: figureStyle(size: 12, color: color)),
        ],
      ),
    );
  }
}
