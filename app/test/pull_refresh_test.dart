// Свайп сверху вниз на любой главной вкладке запускает синхронизацию.
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

void main() {
  for (final path in ['/', '/workout', '/duels', '/rating', '/profile']) {
    testWidgets('потянуть вниз на $path — синхронизация', (t) async {
      t.view.physicalSize = const Size(412, 915);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
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
        for (final id in ['home', 'workout', 'duels', 'rating', 'profile']) ...{
          'hint_seen_$id': true,
          'guide_done_$id': true,
        },
      });
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(container: c, child: const IronRiseApp()),
      );
      c.read(routerProvider).go(path);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      // Тянем из верхней части экрана, под шапкой.
      await t.fling(
        find.byType(RefreshIndicator).first,
        const Offset(0, 400),
        1500,
        warnIfMissed: false,
      );
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      // Без аккаунта — подсказка войти: значит, обновление сработало.
      expect(
        find.textContaining('Синхронизация — с аккаунтом'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 3));
    });
  }
}
