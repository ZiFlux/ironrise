import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:ironrise/state/body_log.dart';

HealthDataPoint point(HealthDataType type, num value, DateTime at) =>
    HealthDataPoint(
      uuid: '$type$at',
      value: NumericHealthValue(numericValue: value),
      type: type,
      unit: HealthDataUnit.NO_UNIT,
      dateFrom: at,
      dateTo: at,
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'watch',
      sourceId: 'com.sec.android.app.shealth',
      sourceName: 'com.sec.android.app.shealth',
    );

void main() {
  final t = DateTime(2026, 11, 13, 8);

  test('точки одного анализа склеиваются в замер, повтор не добавляется', () {
    final points = [
      point(HealthDataType.BODY_FAT_PERCENTAGE, 18.4, t),
      point(
        HealthDataType.LEAN_BODY_MASS,
        65.3,
        t.add(const Duration(seconds: 2)),
      ),
      point(HealthDataType.BODY_WATER_MASS, 47.8, t),
      point(HealthDataType.BASAL_ENERGY_BURNED, 1720, t),
      point(
        HealthDataType.BODY_FAT_PERCENTAGE,
        18.0,
        t.add(const Duration(days: 3)),
      ),
    ];
    final first = mergeComposition(const [], points);
    expect(first, hasLength(2));
    final a = first.first;
    expect(
      (a.fatPct, a.leanKg, a.waterKg, a.bmrKcal),
      (18.4, 65.3, 47.8, 1720),
    );
    expect(mergeComposition(first, points), isEmpty);
  });

  test('проценты массы — от ближайшего веса; срок взвешивания 3 дня', () {
    final log = [
      BodyMeasurement(
        at: t,
        fatPct: 18.4,
        leanKg: 65.3,
        waterKg: 47.8,
        source: 'sh',
      ),
      BodyMeasurement(at: t.subtract(const Duration(hours: 1)), weightKg: 80),
    ];
    final s = bodySnapshot(log);
    expect(s.weightKg, 80);
    expect(s.leanPct, closeTo(81.6, 0.1));
    expect(s.waterPct, closeTo(59.75, 0.01));
    expect(weighInDue(log, t.add(const Duration(days: 2))), isFalse);
    expect(weighInDue(log, t.add(const Duration(days: 3))), isTrue);
    expect(weighInDue(const [], t), isTrue);
  });

  test('изменение веса за 30 дней', () {
    final log = [
      BodyMeasurement(at: t, weightKg: 78.5),
      BodyMeasurement(at: t.subtract(const Duration(days: 31)), weightKg: 80),
    ];
    expect(weightChange(log, t), closeTo(-1.5, 1e-9));
  });
}
