// Лист одежды на разных фигурах и в позах: проверить, что вещи не рвутся,
// не дырявые и тянутся по телу. Не входит в обычные тесты (лежит в tool/).
//
// Запуск из app/:
//   flutter test tool/render_clothes_test.dart --dart-define=OUT=<папка>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/avatar/avatar_view.dart';
import 'package:ironrise/avatar/body_frame.dart';
import 'package:ironrise/game/body_part.dart';

const _out = String.fromEnvironment('OUT');

void main() {
  if (_out.isEmpty) {
    test('OUT не задан — пропуск', () {});
    return;
  }
  final key = GlobalKey();
  const bg = Color(0xFF120D10); // AppColors.background

  Future<void> sheet(
    WidgetTester tester,
    String path,
    List<(String, Widget)> cells,
  ) async {
    await tester.binding.setSurfaceSize(Size(cells.length * 200.0 + 40, 500));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Material(
            color: bg,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  for (final (label, child) in cells)
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          SizedBox(width: 200, height: 400, child: child),
                          const SizedBox(height: 10),
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFB9A9AE),
                              fontSize: 13,
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

  testWidgets('одежда на фигурах и в позах', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader('Inter')
        ..addFont(
          File('assets/fonts/Inter-Regular.ttf')
              .readAsBytes()
              .then((b) => ByteData.sublistView(b)),
        );
      await loader.load();
    });
    final cases = <(String, num, BodyBuild, AvatarPose)>[
      ('ур.1 худ.', 1, BodyBuild.slim, AvatarPose.relaxed),
      ('ур.1 крупн.', 1, BodyBuild.heavy, AvatarPose.relaxed),
      ('ур.40', 40, BodyBuild.average, AvatarPose.relaxed),
      ('ур.40 бицепс', 40, BodyBuild.average, AvatarPose.doubleBiceps),
      ('ур.40 широч.', 40, BodyBuild.average, AvatarPose.latSpread),
      ('ур.40 за голов.', 40, BodyBuild.average, AvatarPose.handsBehindHead),
      ('ур.40 победа', 40, BodyBuild.average, AvatarPose.victory),
    ];
    for (final sex in AvatarSex.values) {
      final s = sex == AvatarSex.male ? 'm' : 'f';
      for (final top in TopKind.values.where((t) => t != TopKind.none)) {
        await sheet(tester, '${s}_верх_${top.name}.png', [
          for (final (label, level, build, pose) in cases)
            (
              label,
              AvatarView(
                levels: {for (final b in BodyPart.values) b: level},
                look: AvatarLook.starter(sex).copyWith(top: top, build: build),
                pose: pose,
                poseT: pose == AvatarPose.relaxed ? 0 : 1,
              ),
            ),
        ]);
      }
      for (final bottom in BottomKind.values) {
        await sheet(tester, '${s}_низ_${bottom.name}.png', [
          for (final (label, level, build, pose) in cases.take(3))
            (
              label,
              AvatarView(
                levels: {for (final b in BodyPart.values) b: level},
                look: AvatarLook.starter(sex)
                    .copyWith(bottom: bottom, build: build, top: TopKind.none),
                pose: pose,
              ),
            ),
        ]);
      }
    }
  });
}
