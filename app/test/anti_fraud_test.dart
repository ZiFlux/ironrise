import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/anti_fraud.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/workout.dart';
import 'package:ironrise/state/heart_rate_state.dart';

final start = DateTime(2026, 11, 11, 19);

/// Подходы раскладываются по упражнениям, по 8 на каждое (лимит справочника).
WorkoutSession sessionWithSets(int sets) {
  final entries = <ExerciseEntry>[];
  for (var left = sets, i = 0; left > 0; left -= 8, i++) {
    var entry = ExerciseEntry(exercise: ExerciseCatalog.all[i]);
    for (var s = 0; s < (left < 8 ? left : 8); s++) {
      entry = entry.withSet(const SetRecord(weight: 8, reps: 12));
    }
    entries.add(entry);
  }
  return WorkoutSession(startedAt: start, entries: entries);
}

/// Пульс каждые 10 секунд по функции от номера отсчёта.
List<PulseSample> pulseFor(Duration span, int Function(int i) bpm) => [
      for (var i = 0; i * 10 <= span.inSeconds; i++) PulseSample(start.add(Duration(seconds: i * 10)), bpm(i)),
    ];

void main() {
  group('разбор Bluetooth-пакета пульса', () {
    test('пульс одним байтом', () => expect(parseHeartRateMeasurement([0x00, 72]), 72));
    test('пульс двумя байтами', () => expect(parseHeartRateMeasurement([0x01, 0x2C, 0x01]), 300));
    test('битый пакет', () => expect(parseHeartRateMeasurement([0x01]), isNull));
  });

  const duration = Duration(minutes: 30);
  final finishedAt = start.add(duration);

  test('без пульса V = 0,5', () {
    expect(AntiFraud.validity(session: sessionWithSets(10), pulse: const [], finishedAt: finishedAt), 0.5);
  });

  test('пульс с циклами «подход — отдых» даёт V = 1', () {
    final pulse = pulseFor(duration, (i) => i % 9 < 3 ? 145 : 110);
    expect(AntiFraud.validity(session: sessionWithSets(10), pulse: pulse, finishedAt: finishedAt), 1);
  });

  test('ровный низкий пульс почти обнуляет V', () {
    final pulse = pulseFor(duration, (_) => 72);
    expect(AntiFraud.validity(session: sessionWithSets(10), pulse: pulse, finishedAt: finishedAt), closeTo(0.18, 1e-9));
  });

  test('пульс только на часть тренировки не считается', () {
    final pulse = pulseFor(const Duration(minutes: 10), (i) => i % 9 < 3 ? 145 : 110);
    expect(AntiFraud.validity(session: sessionWithSets(10), pulse: pulse, finishedAt: finishedAt), 0.5);
  });

  test('слишком много подходов за время тренировки', () {
    final pulse = pulseFor(duration, (i) => i % 9 < 3 ? 145 : 110);
    expect(AntiFraud.validity(session: sessionWithSets(60), pulse: pulse, finishedAt: finishedAt), closeTo(0.3, 1e-9));
  });
}
