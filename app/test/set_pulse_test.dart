import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/anti_fraud.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/set_pulse.dart';
import 'package:ironrise/game/workout.dart';

// П. 106: метки подходов и сводка пульса по каждому подходу.
void main() {
  final start = DateTime(2026, 11, 16, 18);
  DateTime at(int s) => start.add(Duration(seconds: s));

  test('время, отдых, пик в окне подхода и минимум на отдыхе', () {
    final entries = [
      ExerciseEntry(
        exercise: ExerciseCatalog.byId('push_up'),
        sets: [
          SetRecord(weight: 0, reps: 12, at: at(120)),
          SetRecord(weight: 0, reps: 10, at: at(240)),
        ],
      ),
    ];
    // Подход 1: пик 150 в 100 с; отдых: пульс падает до 105 к 180 с; подход 2: пик 158.
    final pulse = [
      PulseSample(at(30), 95),
      PulseSample(at(100), 150),
      PulseSample(at(150), 120),
      PulseSample(at(180), 105),
      PulseSample(at(230), 158),
    ];
    final got = setPulses(startedAt: start, entries: entries, pulse: pulse);
    expect(got, hasLength(2));
    final (id1, i1, first) = got[0];
    expect((id1, i1), ('push_up', 0));
    expect(first.t, 120);
    expect(first.rest, isNull);
    expect(first.peak, 150);
    expect(first.base, isNull);
    final (_, i2, second) = got[1];
    expect(i2, 1);
    expect(second.t, 240);
    expect(second.rest, 120);
    expect(second.peak, 158);
    // Отдых — от 140 с (120 + 20) до 180 с (240 − 60): минимум 105.
    expect(second.base, 105);
  });

  test('без пульса (нет согласия) — только время и отдых', () {
    final entries = [
      ExerciseEntry(
        exercise: ExerciseCatalog.byId('push_up'),
        sets: [
          SetRecord(weight: 0, reps: 12, at: at(60)),
          SetRecord(weight: 0, reps: 12, at: at(150)),
        ],
      ),
    ];
    final got = setPulses(startedAt: start, entries: entries, pulse: const []);
    expect(got.map((e) => (e.$3.t, e.$3.rest, e.$3.peak, e.$3.base)), [
      (60, null, null, null),
      (150, 90, null, null),
    ]);
  });

  test('метки тренировки сохраняются и читаются обратно', () {
    final s = WorkoutSession(startedAt: start)
        .withEvent(WorkoutEventKind.exerciseOpen, exerciseId: 'push_up')
        .withEvent(WorkoutEventKind.restSkip);
    final back = WorkoutSession.fromJson(s.toJson());
    expect(back.events.map((e) => (e.kind, e.exerciseId)), [
      (WorkoutEventKind.exerciseOpen, 'push_up'),
      (WorkoutEventKind.restSkip, null),
    ]);
  });
}
