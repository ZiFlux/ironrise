import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/wellbeing.dart';
import 'package:ironrise/state/program_state.dart';
import 'package:ironrise/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
}

void main() {
  test('«тяжело» два раза подряд облегчает следующую тренировку', () async {
    final c = await container();
    final program = c.read(programProvider.notifier);
    expect((await program.recordWellbeing(Feeling.hard)).easeNext, isFalse);
    expect((await program.recordWellbeing(Feeling.hard)).easeNext, isTrue);
    expect(c.read(programProvider).today.exercises.every((e) => e.sets == 1), isTrue);
  });

  test('«нормально» между ними сбрасывает счёт', () async {
    final c = await container();
    final program = c.read(programProvider.notifier);
    await program.recordWellbeing(Feeling.hard);
    await program.recordWellbeing(Feeling.ok);
    expect((await program.recordWellbeing(Feeling.hard)).easeNext, isFalse);
  });

  test('боль в колене меняет план, повтор — совет к врачу', () async {
    final c = await container();
    final program = c.read(programProvider.notifier);
    final first = await program.recordWellbeing(Feeling.pain, zone: PainZone.knee);
    expect(first.repeatedPain, isFalse);
    expect(first.plan!.adjustments, isNotEmpty);
    final second = await program.recordWellbeing(Feeling.pain, zone: PainZone.knee);
    expect(second.repeatedPain, isTrue);
  });
}
