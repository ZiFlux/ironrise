import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/body_part.dart';
import '../game/progression.dart';
import '../game/training_stats.dart';
import '../state/hero.dart';
import '../state/providers.dart';
import '../state/rest_steps.dart';
import '../state/training_log.dart';
import '../theme.dart';
import 'status_toast.dart';

const _recapKey = 'week_recap_shown_v1';

/// Итог недели (PLAN 4.8, п. 2): тренировки, опыт по частям, новые уровни, сила.
class WeekRecap {
  const WeekRecap({
    required this.weekStart,
    required this.workouts,
    required this.planned,
    required this.gains,
    required this.levelUps,
    required this.powerBefore,
    required this.powerAfter,
    required this.streak,
  });

  final DateTime weekStart;
  final int workouts;
  final int planned;
  final Map<BodyPart, int> gains;
  final Map<BodyPart, int> levelUps;
  final int powerBefore;
  final int powerAfter;
  final int streak;

  bool get isEmpty => workouts == 0;

  /// Неделя, которая кончилась к [now]: в воскресенье вечером — текущая,
  /// в понедельник — прошлая.
  static DateTime weekFor(DateTime now) {
    final monday = StatDates.mondayOf(now);
    return now.weekday == DateTime.sunday
        ? monday
        : monday.subtract(const Duration(days: 7));
  }

  static WeekRecap of(
    List<LoggedWorkout> log,
    HeroProfile hero,
    DateTime weekStart,
    DateTime now,
  ) {
    final end = weekStart.add(const Duration(days: 7));
    final week = log.where(
      (w) => !w.at.isBefore(weekStart) && w.at.isBefore(end),
    );
    final gains = <BodyPart, int>{};
    for (final w in week) {
      for (final g in w.gains.entries) {
        gains[g.key] = (gains[g.key] ?? 0) + g.value;
      }
    }
    // Опыт на начало недели: всё, что получено с её начала, вычитаем.
    final since = <BodyPart, int>{};
    for (final w in log.where((w) => !w.at.isBefore(weekStart))) {
      for (final g in w.gains.entries) {
        since[g.key] = (since[g.key] ?? 0) + g.value;
      }
    }
    final xpStart = {
      for (final p in BodyPart.values)
        p: ((hero.xp[p] ?? 0) - (since[p] ?? 0)).clamp(0, 1 << 30),
    };
    final xpEnd = {
      for (final p in BodyPart.values) p: xpStart[p]! + (gains[p] ?? 0),
    };
    final before = Progression.levels(xpStart);
    final after = Progression.levels(xpEnd);
    final streak = hero.currentStreak(now);
    return WeekRecap(
      weekStart: weekStart,
      workouts: week.length,
      planned: hero.trainingDays.length,
      gains: gains,
      levelUps: {
        for (final p in BodyPart.values)
          if (after[p]! > before[p]!) p: after[p]! - before[p]!,
      },
      powerBefore: Progression.power(before, streak),
      powerAfter: Progression.power(after, streak),
      streak: streak,
    );
  }

  /// Текст «поделиться».
  String get shareText {
    final ups = levelUps.entries
        .map((e) => '${e.key.label.toLowerCase()} +${e.value}')
        .join(', ');
    return 'Моя неделя в IronRise: $workouts из $planned тренировок'
        '${ups.isEmpty ? '' : ', $ups ур.'}, сила ${powerAfter - powerBefore >= 0 ? '+' : ''}'
        '${powerAfter - powerBefore}, серия $streak 🔥';
  }
}

/// Раз в неделю (воскресенье вечером или понедельник) — окно итога.
Future<void> maybeShowWeekRecap(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  final eligible =
      (now.weekday == DateTime.sunday && now.hour >= 18) ||
      now.weekday == DateTime.monday;
  if (!eligible) return;
  final hero = ref.read(heroProvider);
  if (hero == null) return;
  final week = WeekRecap.weekFor(now);
  final key = '${week.year}-${week.month}-${week.day}';
  final prefs = ref.read(prefsProvider);
  if (prefs.getString(_recapKey) == key) return;
  final recap = WeekRecap.of(ref.read(trainingLogProvider), hero, week, now);
  if (recap.isEmpty) return;
  await prefs.setString(_recapKey, key);
  if (!context.mounted) return;
  await showWeekRecap(context, recap);
}

Future<void> showWeekRecap(BuildContext context, WeekRecap recap) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => WeekRecapView(recap: recap),
    );

class WeekRecapView extends StatelessWidget {
  const WeekRecapView({super.key, required this.recap, this.compact = false});

  final WeekRecap recap;

  /// В статистике — без кнопки и заголовка покрупнее.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final delta = recap.powerAfter - recap.powerBefore;
    final maxGain = recap.gains.values.fold(1, (m, v) => v > m ? v : m);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, compact ? 16 : 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compact ? 'Итог недели' : 'Неделя позади',
              style: TextStyle(
                fontSize: compact ? 15 : 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (i, (value, label)) in [
                  ('${recap.workouts} из ${recap.planned}', 'тренировок'),
                  ('${delta >= 0 ? '+' : ''}$delta', 'сила'),
                  ('${recap.streak}', 'серия'),
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.raised,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(value, style: figureStyle(size: 18)),
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
                ],
              ],
            ),
            const SizedBox(height: 14),
            for (final p in BodyPart.values)
              if ((recap.gains[p] ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          p.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: recap.gains[p]! / maxGain,
                            minHeight: 6,
                            color: p.color,
                            backgroundColor: AppColors.raised,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 86,
                        child: Text(
                          '+${recap.gains[p]} XP'
                          '${recap.levelUps[p] != null ? ' ▲${recap.levelUps[p]}' : ''}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            color: recap.levelUps[p] != null
                                ? accent
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            if (!compact) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: recap.shareText));
                  showStatus(
                    'Итог скопирован — вставь в сторис или чат',
                    kind: StatusKind.success,
                  );
                },
                icon: const Icon(LucideIcons.copy, size: 16),
                label: const Text('Скопировать, чтобы поделиться'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Обёртка главной: при открытии раз в неделю показывает итог.
class WeekRecapGate extends ConsumerStatefulWidget {
  const WeekRecapGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WeekRecapGate> createState() => _WeekRecapGateState();
}

class _WeekRecapGateState extends ConsumerState<WeekRecapGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      maybeShowWeekRecap(context, ref);
      // Вечером в день отдыха — шаги из Health Connect немного качают кардио.
      maybeClaimRestSteps(ref);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
