/// «Не получается упражнение?» (п. 80): советы и замена на упражнение с той же
/// нагрузкой на те же мышцы — сначала проще или такое же по сложности.
library;

import 'exercise_catalog.dart';
import 'muscles.dart';
import 'program.dart';

/// Насколько [b] нагружает те же мышцы, что [a]: 0 — совсем другие, 1 — те же доли.
double muscleOverlap(Exercise a, Exercise b) {
  final ma = exerciseMuscles[a.id] ?? const <Muscle, double>{};
  final mb = exerciseMuscles[b.id] ?? const <Muscle, double>{};
  var sum = 0.0;
  for (final e in ma.entries) {
    final other = mb[e.key];
    if (other != null) sum += e.value < other ? e.value : other;
  }
  return sum;
}

/// Минимальное совпадение по мышцам, чтобы замена считалась равноценной.
const minSwapOverlap = 0.45;

/// До [limit] замен для [original]: та же единица (повторы / секунды), доступно
/// с инвентарём, не в тренировке и не исключено; не сложнее исходного.
/// Порядок: совпадение по мышцам, затем проще, затем то же движение.
List<Exercise> swapOptions(
  Exercise original, {
  required Set<String> inWorkout,
  required Equipment equipment,
  Set<String> excluded = const {},
  int limit = 3,
}) {
  final scored = <(Exercise, double)>[];
  for (final e in ExerciseCatalog.all) {
    if (e.id == original.id ||
        e.unit != original.unit ||
        e.difficulty > original.difficulty ||
        inWorkout.contains(e.id) ||
        excluded.contains(e.id) ||
        !isAvailable(e.id, equipment)) {
      continue;
    }
    final overlap = muscleOverlap(original, e);
    final samePattern = e.pattern.isNotEmpty && e.pattern == original.pattern;
    if (overlap < (samePattern ? 0.3 : minSwapOverlap)) continue;
    // Совпадение по мышцам важнее всего; проще и то же движение — небольшой плюс.
    final score =
        overlap +
        (samePattern ? 0.15 : 0) +
        (original.difficulty - e.difficulty) * 0.05;
    scored.add((e, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored.take(limit)) s.$1];
}

/// Общие советы, если упражнение не идёт: по типу нагрузки.
List<String> struggleTips(Exercise exercise) => [
  if (exercise.usesWeight)
    'Сбрось вес на 20–30 % и сделай подход чисто. Техника важнее цифры: вес вернётся за пару тренировок.'
  else if (exercise.unit == ExerciseUnit.seconds)
    'Держи столько, сколько держишь ровно, и добавляй по 5 секунд. Лучше три коротких подхода, чем один с прогибом.'
  else
    'Сделай столько повторов, сколько выходит чисто, хоть 3. Остальное добери облегчённым вариантом ниже.',
  'Уменьши амплитуду: опускайся не до конца, пока не окрепнешь. Глубину добавляй постепенно.',
  'Двигайся медленнее: 2 секунды вниз, пауза, вверх. Медленно — значит под контролем.',
  'Больно в суставе — остановись. Мышечное жжение нормально, острая боль — нет.',
];
