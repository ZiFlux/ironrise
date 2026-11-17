import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/exercise_swap.dart';
import 'package:ironrise/game/program.dart';

void main() {
  test('замены: не сложнее, та же единица, те же мышцы, не из тренировки', () {
    for (final e in ExerciseCatalog.all) {
      final options = swapOptions(
        e,
        inWorkout: {e.id},
        equipment: Equipment.gym,
      );
      for (final o in options) {
        expect(o.difficulty, lessThanOrEqualTo(e.difficulty));
        expect(o.unit, e.unit);
        expect(o.id, isNot(e.id));
      }
    }
  });
}
