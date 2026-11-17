// Иконки из знака IronRise (widgets/logo_mark.dart): приложение, адаптивный слой,
// часы и сайт. Запуск из app/: flutter test tool/render_icons_test.dart
// Потом: dart run flutter_launcher_icons и powershell -File ../tools/make-dev-icons.ps1
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/theme.dart';
import 'package:ironrise/widgets/logo_mark.dart';

const _bg = AppColors.background;

void main() {
  final key = GlobalKey();

  Future<void> render(
    WidgetTester tester,
    String path,
    double size,
    Widget child,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: SizedBox.square(dimension: size, child: child),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  /// Знак по центру: [share] — доля стороны, которую он занимает.
  Widget mark(double share, {Color? background, bool round = false}) =>
      Container(
        decoration: BoxDecoration(
          color: background,
          shape: round ? BoxShape.circle : BoxShape.rectangle,
        ),
        child: FractionallySizedBox(
          widthFactor: share,
          heightFactor: share,
          child: CustomPaint(
            painter: LogoPainter(
              accent: AccentOption.sunset.color,
              letters: AccentOption.sunset.onColor,
              filled: true,
            ),
          ),
        ),
      );

  testWidgets('иконки из знака', (tester) async {
    tester.view.physicalSize = const Size(1100, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Обычная иконка (старые лаунчеры) и слой адаптивной (безопасная зона ~66 %).
    await render(
      tester,
      'assets/icon/icon.png',
      1024,
      mark(0.74, background: _bg),
    );
    await render(tester, 'assets/icon/foreground.png', 1024, mark(0.5));
    // Часы: круглая иконка по плотностям.
    const watch = {
      'mdpi': 48.0,
      'hdpi': 72.0,
      'xhdpi': 96.0,
      'xxhdpi': 144.0,
      'xxxhdpi': 192.0,
    };
    for (final e in watch.entries) {
      await render(
        tester,
        '../watch/wearos/app/src/main/res/mipmap-${e.key}/ic_launcher.png',
        e.value,
        mark(0.62, background: _bg, round: true),
      );
    }
    // Сайт.
    await render(
      tester,
      '../site/img/icon.png',
      512,
      mark(0.74, background: _bg),
    );
  });
}
