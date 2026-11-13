import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/session_builder.dart';

PlannedExercise _p(String id) => PlannedExercise(
  id,
  sets: 2,
  repsMin: id == 'plank' ? 20 : 10,
  repsMax: id == 'plank' ? 30 : 12,
  repsInReserve: 3,
);

/// Фиксированный день для тестов: присед, жим, тяга блока, планка.
final gymDayA = ProgramDay('A', 'Тренировка А', [
  for (final id in ['barbell_squat', 'bench_press', 'lat_pulldown', 'plank'])
    _p(id),
]);

/// Дома: приседания, отжимания, тяга гантели, планка.
final homeDayA = ProgramDay('A', 'Тренировка А', [
  for (final id in ['bodyweight_squat', 'push_up', 'db_row', 'plank']) _p(id),
]);

/// Дни «Старта» новичка из генератора.
List<ProgramDay> startDays(Equipment equipment) => SessionBuilder.days(
  level: TrainingLevel.novice,
  sessionsPerWeek: 3,
  equipment: equipment,
  stepOf: (_) => 1,
  start: true,
);
