import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/state/hero.dart';

// П. 100: главная цель и до двух дополнительных сохраняются и читаются обратно.
void main() {
  HeroProfile hero({List<Goal> extra = const []}) => HeroProfile.create(
    nickname: 'Атлет',
    goal: Goal.strength,
    extraGoals: extra,
    format: TrainingFormat.fullBody,
    trainingDays: const [0, 2, 4],
    body: const BodyStats(),
    avatarSex: AvatarSex.male,
  );

  test('дополнительные цели переживают сохранение', () {
    final back = HeroProfile.decode(
      hero(extra: [Goal.endurance, Goal.fatLoss]).encode(),
    );
    expect(back.goal, Goal.strength);
    expect(back.extraGoals, [Goal.endurance, Goal.fatLoss]);
  });

  test('старое сохранение без доп. целей читается', () {
    final back = HeroProfile.decode(hero().encode());
    expect(back.extraGoals, isEmpty);
  });

  test('смена целей через copyWith', () {
    final h = hero().copyWith(goal: Goal.endurance, extraGoals: [Goal.mass]);
    expect(h.goal, Goal.endurance);
    expect(h.extraGoals, [Goal.mass]);
  });
}
