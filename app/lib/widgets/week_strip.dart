import 'package:flutter/material.dart';

import '../game/calendar.dart';
import '../game/training_format.dart';
import '../state/hero.dart';
import '../theme.dart';

/// Календарь недели на главной: тренировка / отдых / пропуск (экран 4).
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.hero});

  final HeroProfile hero;

  @override
  Widget build(BuildContext context) {
    final days = ActivityCalendar.week(
      today: DateTime.now(),
      activeDays: hero.activeDays,
      trainingDays: hero.trainingDays,
      maxRestDays: hero.maxRestDays,
      startDay: hero.createdAt,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [for (final d in days) Expanded(child: _DayCell(day: d))],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});

  final CalendarDay day;

  static const _labels = {
    DayKind.none: '',
    DayKind.trained: 'тренировка',
    DayKind.rest: 'отдых',
    DayKind.missed: 'пропуск',
    DayKind.upcomingTraining: 'по плану тренировка',
    DayKind.upcomingRest: 'по плану отдых',
  };

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final weekday = weekdayShort[day.date.weekday - 1];
    return Semantics(
      label: '$weekday ${day.date.day}, ${_labels[day.kind]}${day.isToday ? ', сегодня' : ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(weekday,
              style: TextStyle(
                fontSize: 12,
                color: day.isToday ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: day.isToday ? FontWeight.w600 : FontWeight.w400,
              )),
          const SizedBox(height: 6),
          _Mark(kind: day.kind, accent: accent, isToday: day.isToday),
          const SizedBox(height: 4),
          Text('${day.date.day}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.kind, required this.accent, required this.isToday});

  final DayKind kind;
  final Color accent;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    final ring = isToday ? Border.all(color: AppColors.textPrimary, width: 1.5) : null;
    switch (kind) {
      case DayKind.trained:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle, border: ring),
          child: const Icon(Icons.check, size: 16, color: AppColors.onAccent),
        );
      case DayKind.missed:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE5484D), width: 1.5),
          ),
          child: const Icon(Icons.close, size: 14, color: Color(0xFFE5484D)),
        );
      case DayKind.upcomingTraining:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: ring ?? Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
          ),
          child: isToday
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                )
              : null,
        );
      case DayKind.rest:
      case DayKind.upcomingRest:
      case DayKind.none:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kind == DayKind.rest ? AppColors.raised : null,
            border: ring,
          ),
          child: kind == DayKind.none
              ? null
              : const Center(
                  child: Text('–', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
        );
    }
  }
}
