import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/exercise_guide.dart';
import 'package:ironrise/game/muscles.dart';

void main() {
  test('у каждого упражнения есть мышцы (доли в сумме 1) и техника', () {
    for (final e in ExerciseCatalog.all) {
      final shares = exerciseMuscles[e.id]!;
      expect(shares.values.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-9));
      // Мышцы принадлежат частям тела, которые упражнение и нагружает.
      for (final m in shares.keys) {
        expect(e.shares.containsKey(m.part), isTrue, reason: '${e.id}: ${m.name}');
      }
      expect(exerciseGuides[e.id]!.steps, isNotEmpty);
    }
  });

  test('очки: подходы × доля × достоверность, как на сервере', () {
    final p = MuscleMath.pointsOf([(exerciseId: 'db_curl', sets: 3)], 0.5);
    expect(p[Muscle.biceps], closeTo(1.2, 1e-9));
    expect(MuscleMath.add(p, p)[Muscle.biceps], closeTo(2.4, 1e-9));
  });

  test('ровная программа — без перекосов и гротеска', () {
    var p = <Muscle, double>{};
    for (final id in exerciseMuscles.keys) {
      p = MuscleMath.add(p, MuscleMath.pointsOf([(exerciseId: id, sets: 4)], 1));
    }
    expect(MuscleMath.grotesque(p), isNull);
    for (final b in MuscleMath.balance(p).values) {
      expect(b, closeTo(1, 0.01));
    }
  });

  test('только жим лёжа — грудь гротескная, бицепс отстаёт', () {
    final p = MuscleMath.add(
      MuscleMath.pointsOf([(exerciseId: 'bench_press', sets: 60)], 1),
      MuscleMath.pointsOf([(exerciseId: 'pull_up', sets: 6)], 1),
    );
    expect(MuscleMath.grotesque(p), Muscle.pecs);
    final b = MuscleMath.balance(p);
    expect(b[Muscle.triceps]!, greaterThan(1));
    expect(b[Muscle.biceps]!, lessThan(1));
  });

  test('мало данных — баланс почти ровный', () {
    final p = MuscleMath.pointsOf([(exerciseId: 'db_curl', sets: 2)], 1);
    expect(MuscleMath.balance(p)[Muscle.biceps]!, lessThan(1.1));
  });
}
