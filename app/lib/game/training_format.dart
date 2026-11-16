/// Формат тренировок пользователя. Задаёт допустимый отдых подряд (PLAN.md, 4.3).
enum TrainingFormat {
  /// Две тренировки и два дня восстановления: загрузка → восстановление (TRAINING_SYSTEM.md 13.6).
  minimum(
    'Минимум',
    '2 тренировки и 2 лёгких дня восстановления в неделю — чтобы начать и не бросить. '
        'Для заметного роста лучше 3',
    [0, 1, 3, 4],
  ),
  fullBody(
    'Фулбоди',
    '3 тренировки в неделю, всё тело за раз. Лучший старт для новичка',
    [0, 2, 4],
  ),
  upperLower(
    'Верх / низ',
    '4 тренировки в неделю: верх и низ тела по очереди',
    [0, 1, 3, 4],
  ),
  split('Сплит', '5 тренировок в неделю, каждый день своя группа мышц', [
    0,
    1,
    2,
    3,
    4,
  ]),
  custom('Свой график', 'Выберите дни сами, минимум 3 в неделю', [0, 2, 4]);

  const TrainingFormat(this.label, this.description, this.defaultDays);

  final String label;
  final String description;

  /// Дни недели по умолчанию: 0 = понедельник … 6 = воскресенье.
  final List<int> defaultDays;
}

const List<String> weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

const int minTrainingDaysPerWeek = 3;

/// Дней загрузки в формате «Минимум».
const int minimumLoadDays = 2;

/// «Минимум»: за каждым днём загрузки идёт день восстановления. Остальные форматы —
/// без дней восстановления. Пары ищутся по порядку недели, с переходом через воскресенье.
Set<int> recoveryDaysOf(TrainingFormat format, Iterable<int> days) {
  if (format != TrainingFormat.minimum) return const {};
  final all = days.toSet();
  final recovery = <int>{};
  // Начинаем с дня, перед которым нет активного — так пары не съезжают.
  final start = [
    for (var d = 0; d < 7; d++)
      if (all.contains(d) && !all.contains((d + 6) % 7)) d,
  ].firstOrNull;
  if (start == null) return const {};
  for (var i = 0; i < 7; i++) {
    final d = (start + i) % 7;
    if (!all.contains(d) || recovery.contains(d)) continue;
    final next = (d + 1) % 7;
    if (all.contains(next)) recovery.add(next);
  }
  return recovery;
}

/// Дни силовой тренировки (загрузки): все дни графика, кроме дней восстановления.
Set<int> loadDaysOf(TrainingFormat format, Iterable<int> days) =>
    {...days}..removeAll(recoveryDaysOf(format, days));

/// «Минимум» по дням загрузки: к каждому добавляется следующий день — восстановление.
Set<int> withRecoveryDays(Iterable<int> loadDays) => {
  for (final d in loadDays) ...{d, (d + 1) % 7},
};

/// График подходит формату: у «Минимума» — ровно 2 дня загрузки не подряд, у
/// остальных — не меньше [minTrainingDaysPerWeek] дней.
bool scheduleValid(TrainingFormat format, Set<int> days) {
  if (format != TrainingFormat.minimum) {
    return days.length >= minTrainingDaysPerWeek;
  }
  return loadDaysOf(format, days).length == minimumLoadDays &&
      recoveryDaysOf(format, days).length == minimumLoadDays;
}

/// Самый длинный перерыв между тренировочными днями с учётом перехода через неделю.
/// Это и есть допустимое число дней отдыха подряд для пользователя.
int maxRestDaysInRow(List<int> days) {
  if (days.isEmpty) return 7;
  final sorted = [...days]..sort();
  var maxGap = 0;
  for (var i = 0; i < sorted.length; i++) {
    final next = i + 1 < sorted.length ? sorted[i + 1] : sorted.first + 7;
    final gap = next - sorted[i] - 1;
    if (gap > maxGap) maxGap = gap;
  }
  return maxGap;
}
