import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/game/workout.dart';
import 'package:ironrise/state/hero.dart';
import 'package:ironrise/state/providers.dart';
import 'package:ironrise/state/training_log.dart';
import 'package:ironrise/state/workout_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Завершил случайно — 5 минут можно вернуться: подходы снова на экране, опыт,
/// журнал и план — как до «Завершить» (без аккаунта всё на телефоне).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container() async {
    final hero = HeroProfile.create(
      nickname: 'Атлет',
      goal: Goal.strength,
      format: TrainingFormat.fullBody,
      trainingDays: const [0, 2, 4],
      body: const BodyStats(),
      avatarSex: AvatarSex.male,
    );
    SharedPreferences.setMockInitialValues({'hero_v1': hero.encode()});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> finishWorkout(ProviderContainer c) async {
    final w = c.read(workoutProvider.notifier)
      ..start()
      ..addExercise(ExerciseCatalog.all.first);
    for (var i = 0; i < 3; i++) {
      w.logSet(0, SetRecord(weight: 20, reps: 10, at: DateTime.now()));
    }
    expect(await w.finish(), isNotNull);
  }

  test('вернуться к тренировке: всё как до «Завершить»', () async {
    final c = await container();
    final xpBefore = Map.of(c.read(heroProvider)!.xp);
    await finishWorkout(c);
    expect(c.read(workoutProvider), isNull);
    expect(c.read(trainingLogProvider), hasLength(1));
    expect(c.read(heroProvider)!.xp, isNot(equals(xpBefore)));

    final w = c.read(workoutProvider.notifier);
    expect(w.undoLeft(), isNotNull);
    expect(await w.resumeFinished(), isNull);

    final session = c.read(workoutProvider);
    expect(session, isNotNull);
    expect(session!.totalSets, 3);
    expect(c.read(trainingLogProvider), isEmpty);
    expect(c.read(heroProvider)!.xp, equals(xpBefore));
    // Второй раз — уже нечего возвращать.
    expect(w.undoLeft(), isNull);
  });

  test('через 5 минут вернуться нельзя', () async {
    final c = await container();
    await finishWorkout(c);
    final w = c.read(workoutProvider.notifier);
    final later = DateTime.now().add(const Duration(minutes: 5, seconds: 1));
    expect(w.undoLeft(later), isNull);
    expect(w.undoLeft(), isNotNull);
  });
}
