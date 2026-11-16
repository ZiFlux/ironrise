import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/main.dart';
import 'package:ironrise/state/health_state.dart';
import 'package:ironrise/state/hero.dart';
import 'package:ironrise/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Шаги с часов подключены — строка шагов на главной.
class _Steps extends HealthNotifier {
  @override
  HealthState build() => HealthState(
    status: HealthStatus.connected,
    stepsToday: 12345,
    metersToday: 8700,
    updatedAt: DateTime.now(),
  );
}

// Баг 16.11: плашка «Пора взвеситься» закрывала строку шагов и расстояния.
void main() {
  for (final (size, scale) in [
    (const Size(360, 640), 1.0),
    (const Size(360, 780), 1.0),
    (const Size(360, 780), 1.3),
    (const Size(412, 915), 1.0),
  ]) {
    testWidgets('главная: шаги и взвешивание не накладываются, $size ×$scale', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final hero = HeroProfile.create(
        nickname: 'Атлет',
        goal: Goal.strength,
        format: TrainingFormat.fullBody,
        trainingDays: const [0, 2, 4],
        body: const BodyStats(),
        avatarSex: AvatarSex.male,
      ).copyWith(xp: {for (final p in BodyPart.values) p: 400});
      SharedPreferences.setMockInitialValues({
        'hero_v1': hero.encode(),
        'health_consent_v1': '{"granted":true}',
        'hint_seen_home': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          healthProvider.overrideWith(_Steps.new),
        ],
      );
      addTearDown(c.dispose);
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        await t.pumpWidget(
          UncontrolledProviderScope(container: c, child: const IronRiseApp()),
        );
        await t.pump();
        await t.pump(const Duration(seconds: 2));
        final steps = find.textContaining('шагов');
        final weigh = find.textContaining('Пора взвеситься');
        expect(steps, findsOneWidget);
        expect(weigh, findsOneWidget);
        final a = t.getRect(steps);
        final b = t.getRect(weigh);
        expect(
          a.overlaps(b),
          isFalse,
          reason: 'шаги $a и плашка $b накладываются',
        );
        // Ничего из блока активности не налезает на шаги.
        for (final other in [
          find.textContaining('Совет'),
          find.byType(FilledButton),
        ]) {
          for (final e in other.evaluate()) {
            final r = t.getRect(find.byWidget(e.widget));
            expect(r.overlaps(a), isFalse, reason: '$r поверх шагов $a');
          }
        }
      } finally {
        FlutterError.onError = previous;
      }
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  }

  // Баг 16.11: в день отдыха по графику главная предлагала силовую.
  testWidgets('день отдыха: на главной кардио, силовой нет', (t) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final today = DateTime.now().weekday - 1;
    final hero = HeroProfile.create(
      nickname: 'Атлет',
      goal: Goal.strength,
      format: TrainingFormat.custom,
      trainingDays: [
        for (var d = 0; d < 7; d++)
          if (d != today) d,
      ].take(3).toList(),
      body: const BodyStats(),
      avatarSex: AvatarSex.male,
    );
    SharedPreferences.setMockInitialValues({
      'hero_v1': hero.encode(),
      'health_consent_v1': '{"granted":true}',
      'hint_seen_home': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(container: c, child: const IronRiseApp()),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(find.text('День отдыха · лёгкое кардио'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byIcon(LucideIcons.dumbbell),
      ),
      findsNothing,
    );
  });
}
