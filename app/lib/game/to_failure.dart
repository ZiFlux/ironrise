import 'exercise_catalog.dart';
import 'session_builder.dart';

/// «До отказа» (п. 73): опытным на последнем подходе базовых упражнений, где
/// отказ безопасен без страховки — тренажёры, гантели, свой вес, изоляция.
/// Тяжёлые свободные веса над собой и на спине (присед и становая со штангой,
/// жим стоя, тяги штанги) — не до отказа: там отказ без страховки опасен.
const toFailureExercises = {
  'machine_chest_press',
  'db_bench_press',
  'bench_press',
  'push_up',
  'dips',
  'pull_up',
  'lat_pulldown',
  'seated_cable_row',
  'leg_press',
  'goblet_squat',
  'bodyweight_squat',
  'leg_extension',
  'leg_curl',
  'lateral_raise',
  'db_curl',
  'hammer_curl',
  'barbell_curl',
  'triceps_pushdown',
};

bool toFailureFor(TrainingLevel level, Exercise exercise) =>
    level == TrainingLevel.advanced && toFailureExercises.contains(exercise.id);

const toFailureTitle = 'Что такое «до отказа»';

const toFailureText =
    'Отказ — момент, когда очередной повтор с правильной техникой уже не '
    'получается. Последний подход до отказа даёт мышцам сильный сигнал к росту.\n\n'
    '• Только последний подход упражнения, не каждый.\n'
    '• Техника важнее числа: как только повтор «ломается» — стоп.\n'
    '• Жим штанги лёжа — только со страхующим или в раме с упорами.\n'
    '• Присед и становая со штангой, жим стоя — не до отказа: без страховки это '
    'опасно для спины и плеч.\n'
    '• Болит сустав — останавливайся сразу, это не отказ мышцы.';
