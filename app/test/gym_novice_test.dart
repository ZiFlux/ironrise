import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/session_builder.dart';

// TRAINING_SYSTEM.md 13.3: новичок в зале на старте — основа со своим весом,
// с инвентарём — 2–3 упражнения; гравитрон вместо подтягиваний.
void main() {
  List<Exercise> plan({required bool start}) => [
    for (final d in SessionBuilder.days(
      level: TrainingLevel.novice,
      sessionsPerWeek: 2,
      equipment: Equipment.gym,
      stepOf: (_) => 0,
      start: start,
    ))
      for (final e in d.exercises) e.exercise,
  ];

  test('старт: присед, отжимания от опоры и гравитрон, инвентаря немного', () {
    final ex = plan(start: true);
    final ids = ex.map((e) => e.id).toSet();
    expect(ids, contains('bodyweight_squat'));
    expect(ids.intersection({'incline_push_up', 'knee_push_up'}), isNotEmpty);
    expect(ids, contains('assisted_pull_up'));
    expect(ex.every((e) => e.difficulty < 3), isTrue);
    final withGear = ex.where((e) => e.gear != ExerciseGear.none).length;
    expect(withGear, inInclusiveRange(2, 5));
  });

  test('после старта — обычная программа зала', () {
    final ids = plan(start: false).map((e) => e.id).toSet();
    expect(ids, contains('lat_pulldown'));
  });
}
