import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/body_part.dart';
import '../game/calendar.dart';
import '../game/exercise_catalog.dart';
import '../game/training_analysis.dart';
import '../game/training_stats.dart';
import '../state/program_state.dart';
import '../state/records_state.dart';
import '../state/training_log.dart';
import '../state/providers.dart';
import '../widgets/line_chart.dart';
import '../widgets/training_analysis_view.dart';
import '../widgets/weigh_in.dart';
import '../widgets/week_recap.dart';
import '../theme.dart';
import '../widgets/format.dart';

/// Статистика тренировок: итоги, активность, объём по неделям, опыт по частям, динамика упражнения.
class TrainingStatsScreen extends ConsumerWidget {
  const TrainingStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(trainingLogProvider);
    final stats = TrainingStats(log);
    final records = ref.watch(recordsProvider);
    final now = DateTime.now();
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: log.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Здесь появятся динамика и итоги после первой тренировки',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _Tiles(
                  items: [
                    // Подписи короткие — четыре плитки в ряд без многоточий.
                    ('Всего', '${stats.workouts}'),
                    ('За месяц', '${stats.inLastDays(30, now)}'),
                    ('Подходов', '${records.sets}'),
                    // От 100 т — без десятых: «128 т» помещается в плитку.
                    (
                      'Поднято',
                      stats.volume >= 100000
                          ? '${(stats.volume / 1000).round()} т'
                          : '${(stats.volume / 1000).toStringAsFixed(1)} т',
                    ),
                  ],
                ),
                if (ref.watch(heroProvider) case final hero?)
                  if (WeekRecap.of(log, hero, WeekRecap.weekFor(now), now)
                      case final recap when !recap.isEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: WeekRecapView(recap: recap, compact: true),
                    ),
                  ],
                if (ref.watch(heroProvider) case final hero?) ...[
                  const SizedBox(height: 20),
                  const _Title('Анализ и прогноз'),
                  TrainingAnalysisView(
                    analysis: TrainingAnalysis(
                      log,
                      level: trainingLevelOf(hero, ref.watch(programProvider)),
                      now: now,
                    ),
                    plannedPerWeek: hero.loadDays.length,
                  ),
                ],
                const SizedBox(height: 20),
                const _Title('Тело'),
                const BodySummary(),
                const SizedBox(height: 20),
                const _Title('Активность за 12 недель'),
                _ActivityGrid(days: stats.activeDays, now: now, accent: accent),
                const SizedBox(height: 24),
                const _Title('Поднятый вес по неделям, кг'),
                _Bars(
                  color: accent,
                  points: [
                    for (final w in stats.weekly(now))
                      (
                        label:
                            '${w.week.day}.${w.week.month.toString().padLeft(2, '0')}',
                        value: w.volume,
                        tip:
                            'Неделя с ${formatDate(w.week)}: ${w.volume.round()} кг, '
                            '${workoutsWord(w.workouts)}',
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const _Title('Опыт по частям тела за 30 дней'),
                _PartGains(gains: stats.gainsInLastDays(30, now)),
                const SizedBox(height: 24),
                _ExerciseProgress(stats: stats, accent: accent),
              ],
            ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
  );
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, (label, value)) in items.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  // Число в одну строку: длинное («94.8 т») ужимается, а не
                  // переносится.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: figureStyle(size: 20),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      ],
    ],
  );
}

/// 12 недель × 7 дней: силовая, кардио, оба.
class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid({
    required this.days,
    required this.now,
    required this.accent,
  });

  final Map<String, Set<WorkoutKind>> days;
  final DateTime now;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    final firstMonday = StatDates.mondayOf(now)
        .subtract(const Duration(days: 7 * (weeks - 1)));
    final cardio = BodyPart.cardio.color;
    Color colorOf(Set<WorkoutKind>? kinds) {
      if (kinds == null || kinds.isEmpty) return AppColors.raised;
      if (kinds.length == 2) return accent;
      return kinds.contains(WorkoutKind.strength)
          ? accent.withValues(alpha: 0.55)
          : cardio.withValues(alpha: 0.7);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cell = (c.maxWidth - (weeks - 1) * 3) / weeks;
            final size = cell.clamp(8.0, 22.0);
            return Row(
              children: [
                for (var w = 0; w < weeks; w++) ...[
                  if (w > 0) const SizedBox(width: 3),
                  Column(
                    children: [
                      for (var d = 0; d < 7; d++) ...[
                        if (d > 0) const SizedBox(height: 3),
                        () {
                          final day = firstMonday.add(
                            Duration(days: w * 7 + d),
                          );
                          final future = day.isAfter(now);
                          return Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: future
                                  ? Colors.transparent
                                  : colorOf(days[dayKey(day)]),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }(),
                      ],
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          children: [
            _Legend(color: accent.withValues(alpha: 0.55), label: 'Силовая'),
            _Legend(color: cardio.withValues(alpha: 0.7), label: 'Кардио'),
            _Legend(color: accent, label: 'Обе'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );
}

typedef _Point = ({String label, double value, String tip});

/// Столбики одной серии; нажатие показывает значение над графиком.
class _Bars extends StatefulWidget {
  const _Bars({required this.points, required this.color});

  final List<_Point> points;
  final Color color;

  @override
  State<_Bars> createState() => _BarsState();
}

class _BarsState extends State<_Bars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final max = points.fold(0.0, (m, p) => p.value > m ? p.value : m);
    final selected = _selected ?? points.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          points.isEmpty ? '' : points[selected].tip,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, p) in points.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selected = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Высота столбика — доля места над подписью: шрифт любого размера влезает.
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: max <= 0
                                  ? 0.02
                                  : (p.value / max).clamp(0.02, 1.0),
                              child: Container(
                                width: 14,
                                decoration: BoxDecoration(
                                  color: i == selected
                                      ? widget.color
                                      : widget.color.withValues(alpha: 0.45),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.label,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _PartGains extends StatelessWidget {
  const _PartGains({required this.gains});

  final Map<BodyPart, int> gains;

  @override
  Widget build(BuildContext context) {
    final max = gains.values.fold(0, (m, v) => v > m ? v : m);
    if (max == 0) {
      return const Text(
        'За месяц опыта пока нет',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      );
    }
    return Column(
      children: [
        for (final part in BodyPart.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(part.label, style: const TextStyle(fontSize: 13)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (gains[part] ?? 0) / max,
                      minHeight: 6,
                      color: part.color,
                      backgroundColor: AppColors.raised,
                    ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${gains[part] ?? 0} XP',
                    textAlign: TextAlign.right,
                    style: figureStyle(
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Динамика выбранного упражнения: лучший подход каждой тренировки.
class _ExerciseProgress extends StatefulWidget {
  const _ExerciseProgress({required this.stats, required this.accent});

  final TrainingStats stats;
  final Color accent;

  @override
  State<_ExerciseProgress> createState() => _ExerciseProgressState();
}

class _ExerciseProgressState extends State<_ExerciseProgress> {
  String? _id;

  @override
  Widget build(BuildContext context) {
    final done = widget.stats.exercisesDone
        .where((id) => ExerciseCatalog.tryById(id) != null)
        .toList();
    if (done.isEmpty) return const SizedBox.shrink();
    final id = _id != null && done.contains(_id) ? _id! : done.first;
    final exercise = ExerciseCatalog.byId(id);
    final weighted = exercise.usesWeight;
    final unit = weighted
        ? 'кг'
        : exercise.unit == ExerciseUnit.seconds
        ? 'с'
        : 'повт.';
    final points = widget.stats.progressOf(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Динамика упражнения'),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in done.take(10))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(ExerciseCatalog.byId(e).name),
                    selected: e == id,
                    onSelected: (_) => setState(() => _id = e),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Динамика — кривой: виден тренд (п. 105).
        LineChart(
          key: ValueKey(id),
          color: widget.accent,
          points: [
            for (final p in points)
              (
                label: '${p.at.day}.${p.at.month.toString().padLeft(2, '0')}',
                value: p.value,
                tip:
                    '${formatDate(p.at)}: ${weighted ? 'расчётный максимум ' : 'лучший подход '}'
                    '${p.value.toStringAsFixed(weighted ? 1 : 0)} $unit',
              ),
          ],
        ),
      ],
    );
  }
}
