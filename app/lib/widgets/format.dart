import '../game/exercise_catalog.dart';
import '../game/workout.dart';

/// 20 → «20», 22.5 → «22,5».
String formatWeight(double kg) =>
    kg % 1 == 0 ? kg.toInt().toString() : kg.toStringAsFixed(1).replaceAll('.', ',');

/// «20 кг × 10», «× 12», «30 с».
String formatSet(Exercise exercise, SetRecord set) {
  final amount = exercise.unit == ExerciseUnit.seconds ? '${set.reps} с' : '× ${set.reps}';
  return exercise.usesWeight ? '${formatWeight(set.weight)} кг $amount' : amount;
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
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'подхода';
  return 'подходов';
}
