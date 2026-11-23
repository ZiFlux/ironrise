import 'dart:math';

import 'exercise_catalog.dart';
import 'workout.dart';

/// Правдоподобие подхода (п. 75 бэклога): невозможные числа не засчитываем,
/// резкий скачок к своим рекордам — переспрашиваем. С юмором, без занудства.
enum SetSanity { ok, jump, absurd }

/// Потолок веса по инвентарю, кг: выше — невозможно (рекорды мира ниже).
/// Тот же потолок проверяет сервер (server/src/game/workout.ts, maxWeightFor).
double maxWeightFor(ExerciseGear gear) => switch (gear) {
  // Доп. вес в упражнениях с собственным весом (пояс, рюкзак).
  ExerciseGear.none => 150,
  // Одна гантель.
  ExerciseGear.dumbbells => 100,
  ExerciseGear.gym => 500,
};

/// Повторов (или секунд) в одном подходе — больше не бывает в нашей программе.
const maxRepsPerSet = 300;

/// [best] — лучший подход игрока в этом упражнении (records_state.dart).
SetSanity checkSet(Exercise exercise, SetRecord set, {SetRecord? best}) {
  if (set.reps > maxRepsPerSet) return SetSanity.absurd;
  if (exercise.usesWeight && set.weight > maxWeightFor(exercise.gear)) {
    return SetSanity.absurd;
  }
  if (best == null) return SetSanity.ok;
  if (exercise.usesWeight && set.weight > 0 && best.weight > 0) {
    // Скачок по расчётному максимуму в полтора раза и хотя бы на 10 кг:
    // 6×15 → 10×30 — да, 20 → 25 кг у новичка — нет.
    final now = _strength(set);
    final was = _strength(best);
    if (now > was * 1.5 && now - was >= 10) return SetSanity.jump;
    return SetSanity.ok;
  }
  // Без веса — по повторам: вдвое больше рекорда и хотя бы на 10.
  if (set.reps > best.reps * 2 && set.reps - best.reps >= 10) {
    return SetSanity.jump;
  }
  return SetSanity.ok;
}

/// Грубая сила подхода по Эпли; повторы до 30 — для сравнения, не для оценки силы.
double _strength(SetRecord s) => s.weight * (1 + min(s.reps, 30) / 30);

const _absurdJokes = [
  'Это на стероидах, да? Такой подход мы не засчитаем — проверь цифры.',
  'Даже легенды железа попросили бы страховку. Похоже на опечатку — исправь.',
  'Штанга погнулась от одного взгляда на эти цифры. Давай по-честному.',
  'Сервер посмотрел на этот вес и ушёл пить протеин. Исправь, пожалуйста.',
];

const _jumpJokes = [
  'Ого, вчера — обычная тренировка, а сегодня — легенда зала?',
  'Креатин подействовал мгновенно? Проверь: может, лишний ноль?',
  'Прогресс за один день — как за полгода. Опечатка или новый рекорд?',
  'Мы рады за тебя, но спросим: это точно не опечатка?',
];

String absurdJoke(Random rng) => _absurdJokes[rng.nextInt(_absurdJokes.length)];

String jumpJoke(Random rng) => _jumpJokes[rng.nextInt(_jumpJokes.length)];
