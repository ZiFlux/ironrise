import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net/push.dart';
import 'router.dart';
import 'state/providers.dart';
import 'state/settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const IronRiseApp(),
  ));
}

class IronRiseApp extends ConsumerWidget {
  const IronRiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    return MaterialApp.router(
      title: 'IronRise',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(accent.color),
      scrollBehavior: const _NoStretchScrollBehavior(),
      routerConfig: ref.watch(routerProvider),
      scaffoldMessengerKey: messengerKey,
    );
  }
}

/// Без растягивания экрана на краях прокрутки (эффект Android 12+).
class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}
