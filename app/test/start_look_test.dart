import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/shop.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/state/hero.dart';

HeroProfile _hero() => HeroProfile.create(
  nickname: 'Тест',
  goal: Goal.values.first,
  format: TrainingFormat.values.first,
  trainingDays: const [0, 2, 4],
  body: const BodyStats(),
  avatarSex: AvatarSex.female,
);

void main() {
  test('новый герой: 14 дней на стартовый образ', () {
    final h = _hero();
    expect(h.startLookOpen(DateTime.now()), isTrue);
    expect(
      h.startLookOpen(DateTime.now().add(const Duration(days: 15))),
      isFalse,
    );
    expect(h.firstDayLook, same(h.look));
  });

  test('при фиксации выдаются только надетые вещи редактора', () {
    final look = AvatarLook.starter(AvatarSex.female).copyWith(
      hair: HairStyle.long,
      top: TopKind.tee,
      topColor: const Color(0xFFE8E8E8),
      accessories: {Accessory.cap},
      build: BodyBuild.solid,
    );
    final ids = ShopCatalog.creatorGrant(look, {}).map((i) => i.id).toList();
    expect(ids, containsAll(['hair_long', 'top_tee', 'tc_white']));
    expect(ids, isNot(contains('acc_cap')));
  });

  test('стартовый образ и телосложение переживают сохранение', () {
    final locked = _hero().copyWith(
      startLook: AvatarLook.starter(AvatarSex.female)
          .copyWith(build: BodyBuild.heavy),
      startLocked: true,
    );
    final back = HeroProfile.decode(locked.encode());
    expect(back.startLook!.build, BodyBuild.heavy);
    expect(back.startLookUntil, isNull);
    expect(back.startLookOpen(DateTime.now()), isFalse);
  });
}
