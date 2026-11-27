import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/widgets/delayed_confirm.dart';

/// «Завершить» тренировку случайно не нажать: кнопка в подтверждении оживает
/// только через 3 секунды.
void main() {
  testWidgets('кнопка подтверждения — через 3 секунды', (t) async {
    bool? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmWithDelay(
              context,
              title: 'Завершить тренировку?',
              message: '…',
              confirm: 'Завершить',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pump();

    FilledButton button() => t.widget(find.byType(FilledButton));
    expect(button().onPressed, isNull);
    expect(find.text('Завершить · 3'), findsOneWidget);

    await t.pump(const Duration(seconds: 2));
    expect(button().onPressed, isNull);
    expect(find.text('Завершить · 1'), findsOneWidget);

    await t.pump(const Duration(seconds: 1));
    expect(button().onPressed, isNotNull);
    await t.tap(find.text('Завершить'));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('«Продолжить» — тренировка идёт дальше', (t) async {
    bool? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmWithDelay(
              context,
              title: 't',
              message: 'm',
              confirm: 'Завершить',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pump();
    await t.tap(find.text('Продолжить'));
    await t.pumpAndSettle();
    expect(result, isFalse);
  });
}
