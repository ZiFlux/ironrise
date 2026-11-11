/// Серия считается в днях. Отдых в пределах формата тренировок её не прерывает,
/// а засчитывается в неё (PLAN.md, 4.3).
class Streak {
  const Streak._();

  /// Новая длина серии после тренировки в день [today].
  static int afterActivity({
    required int currentStreak,
    required DateTime? lastActiveDay,
    required DateTime today,
    required int maxRestDays,
  }) {
    if (lastActiveDay == null) return 1;
    final restDays = _daysBetween(lastActiveDay, today) - 1;
    if (restDays < 0) return currentStreak;
    if (restDays > maxRestDays) return 1;
    return currentStreak + restDays + 1;
  }

  /// Серия на сегодня: если отдых уже превысил лимит, она сгорела.
  static int current({
    required int streakDays,
    required DateTime? lastActiveDay,
    required DateTime today,
    required int maxRestDays,
  }) {
    if (lastActiveDay == null) return 0;
    final restSoFar = _daysBetween(lastActiveDay, today) - 1;
    return restSoFar > maxRestDays ? 0 : streakDays;
  }

  static int _daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;
}
