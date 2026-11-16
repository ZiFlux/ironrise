import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/net/api_client.dart';
import 'package:ironrise/screens/ban_screen.dart';
import 'package:ironrise/state/account_state.dart';
import 'package:ironrise/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Баг 66б: после бана игрок продолжал играть.

void main() {
  test('бан — не отказ по существу: тренировка остаётся в очереди', () {
    const banned = ApiException(403, 'Account banned: накрутка');
    expect(banned.isBanned, isTrue);
    expect(banned.banReason, 'накрутка');
    expect(banned.isRejected, isFalse);
    expect(const ApiException(409, 'Conflict').isRejected, isTrue);
    expect(const ApiException(403, 'Forbidden').isBanned, isFalse);
  });

  test('блокировка переживает перезапуск и снимается', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    expect(c.read(banProvider), isNull);
    await c.read(banProvider.notifier).set('накрутка');
    final restarted = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    expect(restarted.read(banProvider), 'накрутка');
    await restarted.read(banProvider.notifier).clear();
    expect(prefs.getString('account_banned'), isNull);
  });

  testWidgets('экран блокировки показывает причину', (tester) async {
    SharedPreferences.setMockInitialValues({'account_banned': 'накрутка'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: BanGate()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Аккаунт заблокирован'), findsOneWidget);
    expect(find.text('Причина: накрутка'), findsOneWidget);
    expect(find.text('Войти в другой аккаунт'), findsOneWidget);
  });
}
