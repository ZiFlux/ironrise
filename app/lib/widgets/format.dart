import '../game/exercise_catalog.dart';
import '../game/program.dart';
import '../game/workout.dart';
import '../l10n/tr.dart';

/// 20 → «20», 22.5 → «22,5».
String formatWeight(double kg) => kg % 1 == 0
    ? kg.toInt().toString()
    : kg.toStringAsFixed(1).replaceAll('.', ',');

/// «20 кг × 10», «× 12», «30 с».
String formatSet(Exercise exercise, SetRecord set) {
  final amount = exercise.unit == ExerciseUnit.seconds
      ? '${set.reps} с'
      : '× ${set.reps}';
  return exercise.usesWeight
      ? '${formatWeight(set.weight)} кг $amount'
      : amount;
}

/// 1:05, 12:40, 1:02:03.
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

String formatMinutes(Duration d) => '${d.inMinutes < 1 ? 1 : d.inMinutes} мин';

String setsWord(int n) {
  final mod10 = n % 10, mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'подход';
  final few = mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14);
  if (few) return 'подхода';
  return 'подходов';
}

/// «8 432» — тысячи через узкий неразрывный пробел, как принято в русском.
String formatThousands(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u202F');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// «Тренировка А · ~32 мин» — подпись кнопки старта по плану.
String planLabel(ProgramDay day) =>
    '${day.title} · ~${day.estimatedDuration.inMinutes} мин';

const _monthsOf = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// «1 декабря».
String formatDate(DateTime d) => '${d.day} ${_monthsOf[d.month - 1]}';

/// Вес без лишнего нуля: 82 → «82», 82.5 → «82,5».
String formatKg(double kg) => kg == kg.roundToDouble()
    ? kg.toStringAsFixed(0)
    : kg.toStringAsFixed(1).replaceAll('.', ',');

/// «3 дня», «5 дней», «1 день» — для предложений вместо «дн.».
String daysWord(int n) => trPlural(n, 'день', 'дня', 'дней', 'day', 'days');

/// «2 тренировки», «5 тренировок».
String workoutsWord(int n) => trPlural(
  n,
  'тренировка',
  'тренировки',
  'тренировок',
  'workout',
  'workouts',
);

/// «1 неделя», «3 недели», «6 недель».
String weeksWord(int n) =>
    trPlural(n, 'неделя', 'недели', 'недель', 'week', 'weeks');

/// «4 упражнения», «1 упражнение».
String exercisesWord(int n) => trPlural(
  n,
  'упражнение',
  'упражнения',
  'упражнений',
  'exercise',
  'exercises',
);

/// «7 движений».
String movesWord(int n) =>
    trPlural(n, 'движение', 'движения', 'движений', 'move', 'moves');
