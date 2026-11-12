import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/state/consent_state.dart';
import 'package:ironrise/state/providers.dart';
import 'package:ironrise/widgets/consent_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [prefsProvider.overrideWithValue(p)]);
}

void main() {
  test('без ответа пульс не разрешён; ответ сохраняется', () async {
    final c = await _container({});
    expect(c.read(healthConsentProvider).asked, isFalse);
    expect(c.read(healthConsentProvider).allowsPulse, isFalse);
    await c.read(healthConsentProvider.notifier).set(true);
    final again = await _container({
      'health_consent_v1':
          (await SharedPreferences.getInstance()).getString('health_consent_v1')!,
    });
    expect(again.read(healthConsentProvider).allowsPulse, isTrue);
    expect(again.read(healthConsentProvider).policyVersion, isNotNull);
  });

  testWidgets('вопрос о пульсе — один раз, «Без пульса» запоминается', (t) async {
    final c = await _container({});
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: ConsentPrompt(child: Scaffold(body: Text('главная'))),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Данные о пульсе'), findsOneWidget);
    await t.tap(find.text('Без пульса'));
    await t.pumpAndSettle();
    expect(find.text('Данные о пульсе'), findsNothing);
    expect(c.read(healthConsentProvider).asked, isTrue);
    expect(c.read(healthConsentProvider).allowsPulse, isFalse);
  });
}
