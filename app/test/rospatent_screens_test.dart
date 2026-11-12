import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/muscles.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/main.dart';
import 'package:ironrise/router.dart';
import 'package:ironrise/state/hero.dart';
import 'package:ironrise/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _load(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    final b = File(f).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
}

// Скриншоты для Роспатента (docs/rospatent). Обычный прогон тестов их пропускает:
//   flutter test test/rospatent_screens_test.dart --update-goldens --dart-define=ENV=beta //     --dart-define=ROUTES=/onboarding,/,/workout,/duels,/rating,/profile,/profile/start-look,/shop,/profile/settings
const routes = String.fromEnvironment('ROUTES');

/// Шрифт иконок из кэша пакетов (в тестах иконки иначе рисуются квадратами).
String _lucideFont() {
  final cache =
      Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['LOCALAPPDATA']}/Pub/Cache';
  final pkg =
      Directory('$cache/hosted/pub.dev')
          .listSync()
          .where((d) => d.path.contains('lucide_icons_flutter-'))
          .map((d) => d.path)
          .toList()
        ..sort();
  return '${pkg.last}/assets/lucide.ttf';
}

void main() {
  setUpAll(() async {
    await _load('Inter', [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
    ]);
    await _load('Roboto', ['assets/fonts/Inter-Regular.ttf']);
    await _load('Unbounded', ['assets/fonts/Unbounded-Medium.ttf']);
    await _load('packages/lucide_icons_flutter/Lucide', [_lucideFont()]);
  });
  for (final path in routes.split(',')) {
    testWidgets(path, skip: routes.isEmpty, (t) async {
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 2.75;
      final h =
          HeroProfile.create(
            nickname: 'Атлет',
            goal: Goal.strength,
            format: TrainingFormat.fullBody,
            trainingDays: const [0, 2, 4],
            body: const BodyStats(),
            avatarSex: AvatarSex.male,
          ).copyWith(
            xp: {
              for (final (i, p) in BodyPart.values.indexed) p: 900 + i * 180,
            },
            coins: 340,
            streakDays: 6,
            lastActiveDay: DateTime.now(),
            look: AvatarLook.starter(AvatarSex.male).copyWith(
              top: TopKind.tank,
              topColor: const Color(0xFF1E2A4A),
              sneakersColor: const Color(0xFFEDEDED),
              hair: HairStyle.short,
            ),
            muscles: MuscleMath.pointsOf([
              (exerciseId: 'bench_press', sets: 30),
              (exerciseId: 'barbell_squat', sets: 16),
              (exerciseId: 'pull_up', sets: 12),
              (exerciseId: 'db_curl', sets: 10),
            ], 1),
          );
      SharedPreferences.setMockInitialValues(
        path == '/onboarding'
            ? {}
            : {
                'hero_v1': h.encode(),
                'health_consent_v1': '{"granted":true}',
                for (final id in [
                  'home',
                  'workout',
                  'duels',
                  'rating',
                  'profile',
                  'shop',
                  'wardrobe',
                ])
                  'hint_seen_$id': true,
              },
      );
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(container: c, child: const IronRiseApp()),
      );
      c.read(routerProvider).go(path);
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final name = path == '/'
          ? 'home'
          : path.substring(1).replaceAll('/', '_');
      await expectLater(
        find.byType(IronRiseApp),
        matchesGoldenFile('../../docs/rospatent/screens/$name.png'),
      );
    });
  }
}
