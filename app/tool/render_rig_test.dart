// Лист рендеров нового скелета (REDESIGN, этап 2): позы и переходы.
// Не входит в обычные тесты (лежит в tool/).
//
// Запуск из app/:
//   flutter test tool/render_rig_test.dart --dart-define=OUT=<папка>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/avatar/body_frame.dart';
import 'package:ironrise/avatar/rig/body.dart';
import 'package:ironrise/avatar/rig/body_painter.dart';
import 'package:ironrise/avatar/rig/rig_painter.dart';
import 'package:ironrise/avatar/rig/skeleton.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/avatar/rig/skeleton_painter.dart';

const _out = String.fromEnvironment('OUT');

void main() {
  if (_out.isEmpty) {
    test('OUT не задан — пропуск', () {});
    return;
  }
  final key = GlobalKey();
  const bg = Color(0xFF120D10);

  Future<void> sheet(
    WidgetTester tester,
    String path,
    List<(String, Widget)> cells,
  ) async {
    await tester.binding.setSurfaceSize(Size(cells.length * 200.0 + 40, 520));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          // Material — без жёлтого подчёркивания «нет темы» у подписей.
          child: Material(
            color: bg,
            child: Container(
              color: bg,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  for (final (label, child) in cells)
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          SizedBox(width: 200, height: 400, child: child),
                          const SizedBox(height: 16),
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFB9A9AE),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_out/$path');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  const poses = [
    ('стойка', RigPoses.relaxed),
    ('двойной бицепс', RigPoses.doubleBiceps),
    ('широчайшие', RigPoses.latSpread),
    ('руки за головой', RigPoses.handsBehindHead),
    ('победа', RigPoses.victory),
  ];

  testWidgets('скелет: позы и переход', (tester) async {
    // Шрифт для подписей: в тестах по умолчанию — квадратики.
    await tester.runAsync(() async {
      final loader = FontLoader('Inter')
        ..addFont(
          File('assets/fonts/Inter-Regular.ttf')
              .readAsBytes()
              .then((b) => ByteData.sublistView(b)),
        );
      await loader.load();
    });
    for (final (s, p) in [('m', Proportions.male), ('f', Proportions.female)]) {
      final rest = RestSkeleton(p);
      final zero = PosedSkeleton(rest, const RigPose({}));
      Widget draw(RigPose pose) => CustomPaint(
        painter: SkeletonPainter(PosedSkeleton(rest, pose), ghost: zero),
      );
      await sheet(tester, '${s}_позы.png', [
        ('покой', draw(const RigPose({}))),
        for (final (label, pose) in poses) (label, draw(pose)),
      ]);
      await sheet(tester, '${s}_переход.png', [
        for (final t in [0.0, 0.25, 0.5, 0.75, 1.0])
          (
            't = $t',
            draw(RigPose.blend(RigPoses.relaxed, RigPoses.doubleBiceps, t)),
          ),
      ]);
    }

    // Этап 2.2: тело на костях — уровни, телосложение, позы.
    for (final (s, sex, p) in [
      ('m', AvatarSex.male, Proportions.male),
      ('f', AvatarSex.female, Proportions.female),
    ]) {
      final rest = RestSkeleton(p);
      Widget body(
        RigPose pose, {
        num level = 10,
        BodyBuild build = BodyBuild.average,
        bool bones = false,
      }) {
        final body = RigBody(
          PosedSkeleton(rest, pose),
          BodyFrame({for (final b in BodyPart.values) b: level}, sex, build),
        );
        return CustomPaint(
          painter: bones
              ? RigBodyPainter(body, SkinTone.tan, bones: true)
              : RigPainter(body, SkinTone.tan, accent: const Color(0xFFFF6B4A)),
        );
      }

      await sheet(tester, '${s}_тело_уровни.png', [
        ('кости', body(RigPoses.relaxed, level: 1, bones: true)),
        for (final l in [1, 10, 25, 60])
          ('уровень $l', body(RigPoses.relaxed, level: l)),
      ]);
      await sheet(tester, '${s}_тело_сложение.png', [
        for (final b in BodyBuild.values)
          (b.label, body(RigPoses.relaxed, level: 1, build: b)),
      ]);
      await sheet(tester, '${s}_тело_позы.png', [
        for (final (label, pose) in poses) (label, body(pose, level: 25)),
      ]);
    }
  });
}
