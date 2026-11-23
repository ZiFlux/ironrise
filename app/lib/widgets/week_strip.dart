import 'logo_mark.dart';

import 'package:flutter/material.dart';

import '../game/calendar.dart';
import '../game/training_format.dart';
import '../state/hero.dart';
import '../state/training_log.dart';
import '../theme.dart';
import 'format.dart';
import 'info_bubble.dart';

/// Календарь недели на главной: тренировка / отдых / пропуск (экран 4).
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.hero, this.log = const []});

  final HeroProfile hero;

  /// Журнал — для облака по нажатию на прошедший день (п. 127).
  final List<LoggedWorkout> log;

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            for (final d in days)
              Expanded(
                child: Tappable(
                  semantics: null,
                  onTap: (c) => showInfoBubble(
                    c,
                    title: dayTitle(d.date),
                    text: dayBubbleText(d, log, hero.maxRestDays),
                  ),
                  child: _DayCell(day: d),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _weekdaysFull = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

/// «Среда, 18» — заголовок облака дня.
String dayTitle(DateTime d) => '${_weekdaysFull[d.weekday - 1]}, ${d.day}';

/// Что было или будет в этот день — текст облака.
String dayBubbleText(CalendarDay day, List<LoggedWorkout> log, int maxRest) {
  final same = [
    for (final w in log)
      if (w.at.year == day.date.year &&
          w.at.month == day.date.month &&
          w.at.day == day.date.day)
        w,
  ];
  if (same.isNotEmpty) {
    return [
      for (final w in same)
        '${w.kind == WorkoutKind.strength ? 'Силовая' : 'Кардио'} '
            '${formatMinutes(w.duration)}, +${w.xp} опыта',
    ].join('\n');
  }
  return switch (day.kind) {
    DayKind.trained => 'Тренировка засчитана',
    DayKind.rest => 'Отдых — серия не сгорела',
    DayKind.missed =>
      'Пропуск: без потери серии можно отдыхать до ${daysWord(maxRest)} подряд',
    DayKind.upcomingTraining =>
      day.isToday ? 'Сегодня по графику тренировка' : 'По графику тренировка',
    DayKind.upcomingRest =>
      day.isToday ? 'Сегодня по графику отдых' : 'По графику отдых',
    DayKind.none => 'Тебя тогда ещё не было в IronRise',
  };
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
      label:
          '$weekday ${day.date.day}, ${_labels[day.kind]}${day.isToday ? ', сегодня' : ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            weekday,
            style: TextStyle(
              fontSize: 12,
              color: day.isToday ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: day.isToday ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          // Число месяца — в облаке по нажатию: место отдано герою.
          _Mark(kind: day.kind, accent: accent, isToday: day.isToday),
        ],
      ),
    );
  }
}

/// Отметка дня. Сделанный — залитый шестигранник, как печать знака IronRise;
/// по плану — контур; пропуск — приглушённый контур с крестиком (не красный:
/// красный в «Закате» путался с акцентом). Сегодня — светлый контур.
class _Mark extends StatelessWidget {
  const _Mark({
    required this.kind,
    required this.accent,
    required this.isToday,
  });

  final DayKind kind;
  final Color accent;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    const size = 24.0;
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    final (Color? fill, Color? stroke, Widget? inner) = switch (kind) {
      DayKind.trained => (
        accent,
        isToday ? AppColors.textPrimary : null,
        Icon(Icons.check, size: 15, color: onAccent),
      ),
      DayKind.missed => (
        null,
        AppColors.textMuted.withValues(alpha: 0.6),
        const Icon(Icons.close, size: 13, color: AppColors.textMuted),
      ),
      DayKind.upcomingTraining => (
        null,
        isToday
            ? AppColors.textPrimary
            : AppColors.textMuted.withValues(alpha: 0.5),
        isToday
            ? Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
      DayKind.rest => (
        AppColors.raised,
        isToday ? AppColors.textPrimary : null,
        const Text(
          '–',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
      DayKind.upcomingRest => (
        null,
        isToday ? AppColors.textPrimary : null,
        const Text(
          '–',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
      DayKind.none => (null, null, null),
    };
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _HexPainter(fill: fill, stroke: stroke),
        child: inner == null ? null : Center(child: inner),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  const _HexPainter({this.fill, this.stroke});

  final Color? fill;
  final Color? stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final hex = LogoPainter.hexagon(size.width / 64);
    if (fill != null) canvas.drawPath(hex, Paint()..color = fill!);
    if (stroke != null) {
      canvas.drawPath(
        hex,
        Paint()
          ..color = stroke!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_HexPainter old) =>
      old.fill != fill || old.stroke != stroke;
}
