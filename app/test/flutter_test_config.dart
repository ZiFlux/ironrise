import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Тесты проверяют русские тексты: система в тестах — русская
/// (по умолчанию flutter test даёт en_US, и приложение ушло бы в английский).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .localeTestValue = const Locale(
    'ru',
    'RU',
  );
  await testMain();
}
