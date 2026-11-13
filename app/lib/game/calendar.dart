/// Календарь недели (PLAN.md, 4.3, экран 4).
/// Прошедший день без тренировки считается отдыхом, пока отдых подряд
/// не превысил лимит формата. Дни сверх лимита — пропуски.
enum DayKind {
  /// День до создания героя.
  none,
  trained,
  rest,
  missed,

  /// Сегодня или позже, по графику тренировка.
  upcomingTraining,

  /// Сегодня или позже, по графику отдых.
  upcomingRest,
}

class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.kind,
    required this.isToday,
  });

  final DateTime date;
  final DayKind kind;
  final bool isToday;
}

/// Ключ дня «2026-11-11» для хранения истории.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Понедельник недели, в которую входит [d].
DateTime mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

class ActivityCalendar {
  const ActivityCalendar._();

  /// Неделя с понедельника по воскресенье, в которую входит [today].
  static List<CalendarDay> week({
    required DateTime today,
    required Set<String> activeDays,
    required List<int> trainingDays,
    required int maxRestDays,
    required DateTime startDay,
  }) {
    final t = dateOnly(today);
    final monday = t.subtract(Duration(days: t.weekday - 1));
    return [
      for (var i = 0; i < 7; i++)
        _day(
          DateTime(monday.year, monday.month, monday.day + i),
          t,
          activeDays,
          trainingDays,
          maxRestDays,
          dateOnly(startDay),
        ),
    ];
  }

  static CalendarDay _day(
    DateTime date,
    DateTime today,
    Set<String> active,
    List<int> trainingDays,
    int maxRestDays,
    DateTime start,
  ) {
    final isToday = date == today;
    DayKind kind;
    if (active.contains(dayKey(date))) {
      kind = DayKind.trained;
    } else if (!date.isBefore(today)) {
      kind = trainingDays.contains(date.weekday - 1)
          ? DayKind.upcomingTraining
          : DayKind.upcomingRest;
    } else if (date.isBefore(start)) {
      kind = DayKind.none;
    } else {
      kind = _restRunIndex(date, active, start) > maxRestDays
          ? DayKind.missed
          : DayKind.rest;
    }
    return CalendarDay(date: date, kind: kind, isToday: isToday);
  }

  /// Какой по счёту это день отдыха подряд (1 — первый после тренировки).
  static int _restRunIndex(DateTime date, Set<String> active, DateTime start) {
    var n = 1;
    var d = DateTime(date.year, date.month, date.day - 1);
    while (!d.isBefore(start) && !active.contains(dayKey(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }
}
