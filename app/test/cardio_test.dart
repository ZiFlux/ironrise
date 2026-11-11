import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/anti_fraud.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/cardio.dart';
import 'package:ironrise/game/game_config.dart';

final start = DateTime(2026, 11, 12, 8);
final session = CardioSession(startedAt: start, activity: CardioActivity.run);
Map<BodyPart, int> xpAll(int v) => {for (final p in BodyPart.values) p: v};

/// Замер каждые 5 секунд на протяжении [minutes] минут.
List<PulseSample> pulse(int minutes, int bpm) => [
  for (var s = 0; s <= minutes * 60; s += 5)
    PulseSample(start.add(Duration(seconds: s)), bpm),
];

void main() {
  test('граница зоны 2 по Карвонену: 70 + 0,6 · (190 − 70) = 142', () {
    expect(CardioScoring.zoneLowerBound(), 142);
  });

  test('30 минут бега в зоне ≈ 180 опыта кардио', () {
    final s = CardioScoring.summarize(
      session: session,
      pulse: pulse(30, 150),
      xpBefore: xpAll(0),
      finishedAt: start.add(const Duration(minutes: 30)),
    );
    expect(s.isVerified, isTrue);
    expect(s.gains.single.part, BodyPart.cardio);
    expect(s.gains.single.xp, 30 * GameConfig.cardioXpPerMinute);
    expect(s.cardio!.zoneMinutes, 30);
  });

  test('без пульса засчитывается половина времени', () {
    final s = CardioScoring.summarize(
      session: session,
      pulse: const [],
      xpBefore: xpAll(0),
      finishedAt: start.add(const Duration(minutes: 30)),
    );
    expect(s.isVerified, isFalse);
    expect(s.gains.single.xp, 90);
  });

  test('с часами, но ниже зоны — не меньше, чем без часов', () {
    final s = CardioScoring.summarize(
      session: session,
      pulse: pulse(30, 110),
      xpBefore: xpAll(0),
      finishedAt: start.add(const Duration(minutes: 30)),
    );
    expect(s.gains.single.xp, 90);
  });

  test('отстающее кардио получает ×1,5, больше 2 часов не считается', () {
    final s = CardioScoring.summarize(
      session: session,
      pulse: const [],
      xpBefore: xpAll(300)..[BodyPart.cardio] = 0,
      finishedAt: start.add(const Duration(hours: 5)),
    );
    expect(s.gains.single.wasLagging, isTrue);
    expect(s.gains.single.xp, (120 * 6 * 0.5 * 1.5).round());
  });

  test('провалы в данных пульса не идут в зону', () {
    final samples = [
      PulseSample(start, 150),
      PulseSample(start.add(const Duration(minutes: 10)), 150),
    ];
    expect(CardioScoring.timeInZone(samples, 142), const Duration(seconds: 15));
  });
}
