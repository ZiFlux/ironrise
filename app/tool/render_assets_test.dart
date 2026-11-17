// Рендер графики, нарисованной кодом (аватар, одежда, позы, ауры), в PNG —
// для архива ассетов и оценки дизайнером. Не входит в обычные тесты (лежит в tool/).
//
// Запуск из app/:
//   flutter test tool/render_assets_test.dart --dart-define=OUT=<папка>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/avatar/avatar_view.dart';
import 'package:ironrise/avatar/body_frame.dart';
import 'package:ironrise/game/aura.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/muscles.dart';
import 'package:ironrise/widgets/aura_flame.dart';

const _out = String.fromEnvironment('OUT');

Map<BodyPart, num> _lv(num n) => {for (final p in BodyPart.values) p: n};

/// Ровная программа: очки всех мышц по эталону (чтобы баланс был 1).
MusclePoints _even(double total) => {
  for (final m in Muscle.values) m: total / Muscle.values.length,
};

void main() {
  if (_out.isEmpty) {
    test('OUT не задан — пропуск', () {});
    return;
  }
  final key = GlobalKey();
  const bg = Color(0xFF141415);

  Future<void> shot(
    WidgetTester tester,
    String path,
    Widget child, {
    Size size = const Size(200, 400),
    int frames = 8,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: bg,
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: bg,
                width: size.width,
                height: size.height,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_out/$path');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Widget avatar(
    AvatarLook look, {
    num level = 10,
    Map<BodyPart, num>? levels,
    MusclePoints muscles = const {},
    AvatarPose pose = AvatarPose.relaxed,
    bool lamp = false,
  }) => AvatarView(
    levels: levels ?? _lv(level),
    look: look,
    muscles: muscles,
    pose: pose,
    poseT: pose == AvatarPose.relaxed ? 0 : 1,
    withLamp: lamp,
  );

  testWidgets('рендер графики аватара', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final sex in AvatarSex.values) {
      final s = sex == AvatarSex.male ? 'm' : 'f';
      final base = AvatarLook.starter(sex);

      // 1. Старт: телосложения на 1-м уровне.
      for (final b in BodyBuild.values) {
        await shot(
          tester,
          '10_аватар_старт/${s}_${b.name}.png',
          avatar(base.copyWith(build: b), level: 1),
        );
      }
      // 2. Прогресс: ровная прокачка от 1 до 60 уровня.
      for (final l in [1, 5, 10, 20, 35, 60]) {
        await shot(
          tester,
          '11_аватар_прогресс/${s}_lvl${l.toString().padLeft(2, '0')}.png',
          avatar(base, level: l, muscles: _even(l * 20.0)),
        );
      }
      // 3. Перекосы: отстающая часть и «гротескная» мышца (шуточный бонус).
      await shot(
        tester,
        '12_аватар_перекос/${s}_ноги_отстают.png',
        avatar(base, levels: {..._lv(20), BodyPart.legs: 4}),
      );
      await shot(
        tester,
        '12_аватар_перекос/${s}_только_грудь_гротеск.png',
        avatar(base, level: 20, muscles: {..._even(200), Muscle.pecs: 400}),
      );
      await shot(
        tester,
        '12_аватар_перекос/${s}_только_бицепс_гротеск.png',
        avatar(base, level: 20, muscles: {..._even(200), Muscle.biceps: 400}),
      );
      await shot(
        tester,
        '12_аватар_перекос/${s}_ровно_для_сравнения.png',
        avatar(base, level: 20, muscles: _even(600)),
      );
      // 4. Позы.
      for (final p in AvatarPose.values) {
        await shot(
          tester,
          '13_аватар_позы/${s}_${p.name}.png',
          avatar(base, level: 25, pose: p),
        );
      }
      // 5. Кожа.
      for (final skin in SkinTone.values) {
        await shot(
          tester,
          '14_аватар_кожа/${s}_${skin.name}.png',
          avatar(base.copyWith(skin: skin), level: 12),
        );
      }
      // 6. Причёски.
      for (final h in HairStyle.values) {
        await shot(
          tester,
          '15_причёски/${s}_${h.name}.png',
          avatar(
            base.copyWith(hair: h, hairColor: const Color(0xFF5A3A24)),
            level: 8,
          ),
          size: const Size(200, 200),
        );
      }
      // 7. Одежда: верх, низ, обувь, аксессуары.
      // 6б. Анатомия: без майки, светлая кожа — видно, как растут мышцы и перекосы.
      final bare = base.copyWith(
        top: sex == AvatarSex.male ? TopKind.none : TopKind.bra,
        skin: SkinTone.light,
      );
      for (final l in [1, 10, 20, 40, 60]) {
        await shot(
          tester,
          '22_анатомия/${s}_lvl${l.toString().padLeft(2, '0')}_ровно.png',
          avatar(bare, level: l, muscles: _even(l * 20.0)),
        );
      }
      for (final (name, m) in [
        ('грудь', Muscle.pecs),
        ('бицепс', Muscle.biceps),
        ('квадрицепс', Muscle.quads),
        ('пресс', Muscle.abs),
        ('широчайшие', Muscle.lats),
      ]) {
        await shot(
          tester,
          '22_анатомия/${s}_lvl20_гротеск_$name.png',
          avatar(bare, level: 20, muscles: {..._even(200), m: 400}),
        );
      }
      await shot(
        tester,
        '22_анатомия/${s}_lvl20_ноги_отстают.png',
        avatar(bare, levels: {..._lv(20), BodyPart.legs: 4}),
      );
      for (final p in AvatarPose.values) {
        await shot(
          tester,
          '22_анатомия/${s}_lvl25_поза_${p.name}.png',
          avatar(bare, level: 25, pose: p, muscles: _even(500)),
        );
      }
      for (final t in TopKind.values) {
        await shot(
          tester,
          '16_одежда_верх/${s}_${t.name}.png',
          avatar(
            base.copyWith(top: t, topColor: const Color(0xFFD23C3C)),
            level: 10,
          ),
        );
      }
      for (final b in BottomKind.values) {
        await shot(
          tester,
          '17_одежда_низ/${s}_${b.name}.png',
          avatar(
            base.copyWith(bottom: b, bottomColor: const Color(0xFF4F6D93)),
            level: 10,
          ),
        );
      }
      for (final sh in ShoeKind.values) {
        await shot(
          tester,
          '18_обувь/${s}_${sh.name}.png',
          avatar(
            base.copyWith(shoes: sh, sneakersColor: const Color(0xFFE5484D)),
            level: 10,
          ),
        );
      }
      for (final a in Accessory.values) {
        await shot(
          tester,
          '19_аксессуары/${s}_${a.name}.png',
          avatar(base.copyWith(accessories: {a}), level: 10),
        );
      }
      // 8. Ауры (кадр анимации).
      for (final k in AuraKind.values) {
        await shot(
          tester,
          '20_ауры/${s}_${k.name}.png',
          AuraHero(kind: k, child: avatar(base, level: 18)),
          frames: 12,
        );
      }
      // 9. Главный экран: герой под лампой.
      await shot(
        tester,
        '21_главный_экран/${s}_лампа.png',
        avatar(base, level: 15, muscles: _even(300), lamp: true),
        size: const Size(320, 480),
      );
    }
  });
}
