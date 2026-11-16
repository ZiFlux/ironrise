// П. 127: элементы, которые что-то значат, нажимаются и показывают облако.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/main.dart';
import 'package:ironrise/router.dart';
import 'package:ironrise/state/hero.dart';
import 'package:ironrise/state/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _open(WidgetTester tester, String path) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final hero = HeroProfile.create(
    nickname: 'Тест',
    goal: Goal.strength,
    format: TrainingFormat.fullBody,
    trainingDays: const [0, 2, 4],
    body: const BodyStats(),
    avatarSex: AvatarSex.male,
  );
  SharedPreferences.setMockInitialValues({
    'hero_v1': hero.encode(),
    'health_consent_v1': '{"granted":true}',
    // Обучение вкладок не мешает — его проверяет guide_test.
    for (final t in ['home', 'workout', 'duels', 'rating', 'profile'])
      'guide_done_$t': true,
  });
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const IronRiseApp()),
  );
  c.read(routerProvider).go(path);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return c;
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 9));
}

void main() {
  testWidgets('сила на главной — облако с объяснением', (tester) async {
    await _open(tester, '/');
    await tester.tap(find.byIcon(LucideIcons.zap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Растёт только от тренировок'), findsOneWidget);
    // Нажатие мимо закрывает облако.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Растёт только от тренировок'), findsNothing);
    await _close(tester);
  });

  testWidgets('день недели — облако дня', (tester) async {
    await _open(tester, '/');
    await tester.tap(find.text('Пн').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('по графику', findRichText: true), findsWidgets);
    await _close(tester);
  });

  testWidgets('«Сегодня · …» на тренировке — неделя по графику', (
    tester,
  ) async {
    await _open(tester, '/workout');
    await tester.tap(find.textContaining('Сегодня ·'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Неделя по графику'), findsOneWidget);
    expect(find.text('Изменить график'), findsOneWidget);
    await _close(tester);
  });
}
