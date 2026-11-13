import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/state/providers.dart';
import 'package:ironrise/widgets/guide.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('во время гайда экран не нажимается, листают только кнопки', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var taps = 0;
    await t.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: TabGuide(
            tab: 'workout',
            child: Scaffold(
              body: Column(
                children: [
                  GuideTarget(
                    id: 'workout.plan',
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('План'),
                    ),
                  ),
                  const SizedBox(height: 300),
                  GuideTarget(
                    id: 'workout.start',
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('Начать'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 800));
    expect(find.text('1/2'), findsOneWidget);
    // Мимо карточки и в окно — ничего не происходит.
    await t.tapAt(const Offset(20, 500));
    await t.tap(find.text('План').first, warnIfMissed: false);
    await t.pump();
    expect(find.text('1/2'), findsOneWidget);
    expect(taps, 0);
    await t.tap(find.text('Далее'));
    await t.pump();
    expect(find.text('2/2'), findsOneWidget);
    await t.tap(find.text('Понятно'));
    await t.pump();
    expect(find.text('2/2'), findsNothing);
    expect(prefs.getBool('guide_done_workout'), isTrue);
  });
}
