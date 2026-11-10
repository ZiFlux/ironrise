/// Формат тренировок пользователя. Задаёт допустимый отдых подряд (PLAN.md, 4.3).
enum TrainingFormat {
  fullBody('Фулбоди', '3 тренировки в неделю, всё тело за раз. Лучший старт для новичка', [0, 2, 4]),
  upperLower('Верх / низ', '4 тренировки в неделю: верх и низ тела по очереди', [0, 1, 3, 4]),
  split('Сплит', '5 тренировок в неделю, каждый день своя группа мышц', [0, 1, 2, 3, 4]),
  custom('Свой график', 'Выберите дни сами, минимум 3 в неделю', [0, 2, 4]);

  const TrainingFormat(this.label, this.description, this.defaultDays);

  final String label;
  final String description;

  /// Дни недели по умолчанию: 0 = понедельник … 6 = воскресенье.
  final List<int> defaultDays;
}

const List<String> weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

const int minTrainingDaysPerWeek = 3;

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
