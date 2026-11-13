import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/main.dart';
import 'package:ironrise/router.dart';
import 'package:ironrise/state/hero.dart';
import 'package:ironrise/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Плитки магазина с подписями эксклюзивов («серия 30 дн.») не вылезают
/// за край — ни при обычном, ни при крупном шрифте (баг «bottom overflow 16 px»).
void main() {
  for (final scale in [1.0, 1.15, 1.3]) {
    for (final (slot, item) in [
      ('Цвет волос', 'Огненные'),
      ('Цвет низа', 'Угли'),
      ('Обувь', 'Пламя'),
      ('Цвет верха', 'Пламя'),
    ]) {
      testWidgets('магазин: $slot, шрифт ×$scale', (t) async {
        // Широкий экран: все слоты и товары в горизонтальных рядах строятся
        // сразу. Высота плитки от ширины не зависит — проверка та же.
        t.view.physicalSize = const Size(3600, 2340);
        t.view.devicePixelRatio = 3;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final hero = HeroProfile.create(
          nickname: 'Атлет',
          goal: Goal.strength,
          format: TrainingFormat.fullBody,
          trainingDays: const [0, 2, 4],
          body: const BodyStats(),
          avatarSex: AvatarSex.male,
        );
        SharedPreferences.setMockInitialValues({
          'hero_v1': hero.encode(),
          'health_consent_v1': '{"granted":true}',
          for (final id in ['home', 'shop', 'wardrobe']) 'hint_seen_$id': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final c = ProviderContainer(
          overrides: [prefsProvider.overrideWithValue(prefs)],
        );
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString());
        try {
          await t.pumpWidget(
            UncontrolledProviderScope(container: c, child: const IronRiseApp()),
          );
          c.read(routerProvider).go('/shop');
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
          await t.tap(find.text(slot));
          await t.pump(const Duration(milliseconds: 500));
          expect(find.text(item), findsWidgets);
          await t.pump(const Duration(milliseconds: 300));
        } finally {
          FlutterError.onError = previous;
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump(const Duration(seconds: 2));
          c.dispose();
        }
        expect(errors.where((e) => e.contains('overflowed')), isEmpty);
      });
    }
  }
}
