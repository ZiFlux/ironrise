import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/set_sanity.dart';
import 'package:ironrise/game/workout.dart';

// П. 75: невозможное не засчитываем, резкий скачок — переспрашиваем.
void main() {
  final curl = ExerciseCatalog.byId('db_curl');
  final bench = ExerciseCatalog.byId('bench_press');
  final pushUp = ExerciseCatalog.byId('push_up');

  test('400 кг на бицепс — невозможно', () {
    expect(
      checkSet(curl, const SetRecord(weight: 400, reps: 10)),
      SetSanity.absurd,
    );
  });

  test('скачок 6×15 → 10×30 — переспросить', () {
    expect(
      checkSet(
        bench,
        const SetRecord(weight: 30, reps: 10),
        best: const SetRecord(weight: 15, reps: 6),
      ),
      SetSanity.jump,
    );
  });

  test('обычный прогресс новичка 20 → 25 кг — без вопросов', () {
    expect(
      checkSet(
        bench,
        const SetRecord(weight: 25, reps: 10),
        best: const SetRecord(weight: 20, reps: 10),
      ),
      SetSanity.ok,
    );
  });

  test('отжимания: 15 → 50 повторов — переспросить, 15 → 20 — нормально', () {
    const best = SetRecord(weight: 0, reps: 15);
    expect(
      checkSet(pushUp, const SetRecord(weight: 0, reps: 50), best: best),
      SetSanity.jump,
    );
    expect(
      checkSet(pushUp, const SetRecord(weight: 0, reps: 20), best: best),
      SetSanity.ok,
    );
  });

  test('первый подход без истории — только потолок', () {
    expect(
      checkSet(bench, const SetRecord(weight: 140, reps: 5)),
      SetSanity.ok,
    );
  });
}
