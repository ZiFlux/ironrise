import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net/app_log.dart';
import 'net/push.dart';
import 'env.dart';
import 'l10n/tr.dart';
import 'router.dart';
import 'screens/ban_screen.dart';
import 'widgets/status_toast.dart';
import 'state/account_state.dart';
import 'state/providers.dart';
import 'state/settings.dart';
import 'theme.dart';
import 'state/summary_publisher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Пока интерфейс рассчитан только на вертикальный экран.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  // Журнал для отладки у тестеров: ловит ошибки с самого старта.
  await AppLog.init(prefs);
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const IronRiseApp(),
    ),
  );
}

class IronRiseApp extends ConsumerWidget {
  const IronRiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    // Язык: из настроек или системный. Смена пересобирает весь интерфейс.
    final language = ref.watch(effectiveLanguageProvider);
    AppLog.startUploading(() => ref.read(apiProvider));
    // Виджет на телефоне и плитка на часах — свежая сводка при каждом изменении.
    ref.watch(summaryPublisherProvider);
    return MaterialApp.router(
      title: 'IronRise',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(accent),
      locale: language.locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Метка DEV: отладочную сборку не перепутать с бетой.
      // Слой плашек статуса (widgets/status_toast.dart) — поверх всех экранов.
      builder: (context, child) {
        // Заблокированный аккаунт — экран блокировки вместо всего приложения.
        final banned = ref.watch(banProvider) != null;
        final app = Stack(
          children: [
            // Ключ по языку — все экраны пересоздаются с новыми текстами.
            KeyedSubtree(
              key: ValueKey(language),
              child: banned ? const BanGate() : child!,
            ),
            Overlay(key: statusOverlayKey),
          ],
        );
        return isDev
            ? Banner(
                message: 'DEV',
                location: BannerLocation.topEnd,
                color: const Color(0xFFFF7A3D),
                child: app,
              )
            : app;
      },
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
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
