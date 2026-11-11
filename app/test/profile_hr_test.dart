import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/cardio.dart';
import 'package:ironrise/game/progression.dart';
import 'package:ironrise/state/hero.dart';

void main() {
  test('возраст и пульс покоя сохраняются и читаются', () {
    const body = BodyStats(age: 30, restingHeartRate: 58);
    final back = BodyStats.fromJson(body.toJson());
    expect(back.age, 30);
    expect(back.restingHeartRate, 58);
  });

  test('зона 2 по своим данным: 58 + 0,6 · (190 − 58) = 137', () {
    expect(CardioScoring.zoneLowerBound(resting: 58, max: 220 - 30), 137);
  });

  test('дробный уровень для плавного роста аватара', () {
    expect(Progression.fractionalLevel(0), 1);
    expect(Progression.fractionalLevel(240), closeTo(3.4, 1e-9));
  });
}
