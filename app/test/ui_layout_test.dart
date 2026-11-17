// Проверка интерфейса: каждый экран на маленьком, обычном и большом телефоне
// и с крупным системным шрифтом. Ловит переполнения и любые ошибки отрисовки,
// а вкладки «Герой», «Дуэли», «Рейтинг» на обычном и большом телефоне проверяет
// на правило «без прокрутки» (на маленьком и с крупным шрифтом прокрутка допустима).
//
// Запуск: flutter test test/ui_layout_test.dart
// Превью экранов с настоящими шрифтами (типичный экран, обычный шрифт) в test/preview/:
//   flutter test test/ui_layout_test.dart --update-goldens --dart-define=PREVIEW=true
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/widgets/screen_hint.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/duel.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/league.dart';
import 'package:ironrise/game/muscles.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/game/workout.dart';
import 'package:ironrise/main.dart';
import 'package:ironrise/router.dart';
import 'package:ironrise/game/combat.dart';
import 'package:ironrise/state/fight_state.dart';
import 'package:ironrise/state/account_state.dart';
import 'package:ironrise/state/joint_state.dart';
import 'package:ironrise/state/duel_state.dart';
import 'package:ironrise/state/hero.dart';
import 'package:ironrise/state/providers.dart';
import 'package:ironrise/state/season_state.dart';
import 'package:ironrise/state/aura_state.dart';
import 'package:ironrise/state/server_game.dart';
import 'package:ironrise/state/workout_state.dart';
import 'package:ironrise/state/training_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Логические размеры экранов (dp).
const _sizes = {
  'маленький 320×568': Size(320, 568),
  'старый 16:9 360×640': Size(360, 640),
  'типичный 360×780': _typical,
  'большой 412×915': Size(412, 915),
};

/// Типичный современный телефон (18:9 и длиннее — почти все с 2018 года).
const _typical = Size(360, 780);

/// Где обязательно «без прокрутки». На маленьком, старом 16:9 и с крупным шрифтом
/// прокрутка — допустимый запасной вариант (FitScreen), наложения — нет.
final _strictSizes = [_typical, const Size(412, 915)];

/// Вкладки, которые по правилу должны помещаться без прокрутки.
const _noScrollTabs = {'/', '/duels', '/rating'};

/// Самый длинный допустимый ник (20 символов) — проверка обрезки.
const _longNick = 'Железный_Богатырь_20';

HeroProfile _hero() {
  final h = HeroProfile.create(
    nickname: _longNick,
    goal: Goal.strength,
    format: TrainingFormat.fullBody,
    trainingDays: const [0, 2, 4],
    body: const BodyStats(),
    avatarSex: AvatarSex.male,
  );
  // Большие числа: серия, монеты и неровные уровни — худший случай для вёрстки.
  return h.copyWith(
    xp: {for (final (i, p) in BodyPart.values.indexed) p: 340 + i * 260},
    coins: 123456,
    // Перекос в жим — на профиле видна гротескная грудь и все строки мышц.
    muscles: MuscleMath.pointsOf([(exerciseId: 'bench_press', sets: 60)], 1),
    streakDays: 30,
    lastActiveDay: DateTime.now(),
  );
}

Fighter _fighter(String id, String name, int level) => Fighter(
  id: id,
  name: name,
  levels: {for (final p in BodyPart.values) p: level},
  streakDays: 12,
);

class _SignedIn extends AccountNotifier {
  @override
  AccountState build() =>
      const AccountState(email: 'very.long.tester.email@ironrise-beta.ru');
}

/// Данные сервера для режима «в аккаунте» — без сети.
/// Совместной тренировки нет — экран показывает «Показать код» и поле ввода.
class _NoJoint extends JointNotifier {
  @override
  Future<JointSession?> build() async => null;
}

List<Override> _serverFakes() {
  final friends = [
    for (var i = 0; i < 9; i++)
      _fighter('f$i', 'Друг с длинным ником $i', 4 + i),
  ];
  return [
    accountProvider.overrideWith(_SignedIn.new),
    jointProvider.overrideWith(_NoJoint.new),
    serverBotsProvider.overrideWith(
      (ref) async => (
        ladder: (
          tier: 2,
          tiers: 13,
          name: 'Подвальная качалка',
          bossId: 'boss',
          bossUnlocked: false,
          wins: 2,
          winsToBoss: 3,
          beaten: {'b0'},
          nextName: 'Фитнес у дома',
        ),
        bots: [
          for (var i = 0; i < 4; i++)
            _fighter('b$i', 'Железный Лёха $i', 5 + i),
          _fighter('boss', 'Гоша-Протеин', 10),
        ],
        results: {'b0': true, 'b1': false},
        nextFightAt: <String, DateTime>{},
        fights: const {'b0': 1, 'b1': 2},
      ),
    ),
    serverFriendsProvider.overrideWith(
      (ref) async => (
        friends: friends,
        incoming: [(userId: 'u1', nickname: 'Очень_Длинный_Ник_01')],
        outgoing: [(userId: 'u2', nickname: 'Ещё_Один_Длинный_Ник')],
        results: {'f0': true},
        fightsLeft: 4,
      ),
    ),
    serverLeagueProvider.overrideWith(
      (ref) async => (
        entries: [
          for (var i = 0; i < 8; i++)
            LeagueEntry(
              name: i == 3 ? _longNick : 'Соперник номер $i',
              points: 120 - i * 9,
              isPlayer: i == 3,
            ),
        ],
        trainedDays: 4,
        wins: 7,
        tier: LeagueTier.silver,
        promoteTop: 2,
        minDaysToPromote: 1,
        demoteBottom: 2,
        lastWeek: (rank: 2, outcome: 'promoted', tierBefore: 0, tierAfter: 1),
      ),
    ),
    auraProvider.overrideWith(_Auras.new),
    seasonProvider.overrideWith(
      (ref) async => SeasonInfo.fromJson({
        'number': 1,
        'name': 'Пробуждение',
        'endsAt': '2026-12-28T00:00:00Z',
        'points': 1234,
        'level': 8,
        'levelPoints': 150,
        'maxLevel': 30,
        'premium': false,
        'freeGranted': 8,
        'premiumGranted': 0,
        'tracks': [
          for (var l = 1; l <= 30; l++)
            {
              'level': l,
              'free': {
                'coins': l == 30 ? 215 : 15,
                'items': [if (l == 5) 'sn_s1', if (l == 15) 'tc_s1'],
                'boosters': {'xp': l == 20 ? 1 : 0, 'coins': l == 10 ? 1 : 0},
              },
              'premium': {
                'coins': 10,
                'items': [if (l == 10) 'hc_s1'],
                'boosters': {'xp': 0, 'coins': 0},
              },
            },
        ],
      }),
    ),
    serverFriendsLeagueProvider.overrideWith(
      (ref) async => [
        for (var i = 0; i < 12; i++)
          LeagueEntry(name: 'Друг $i', points: 90 - i * 5, isPlayer: i == 5),
      ],
    ),
    serverAttacksProvider.overrideWith(
      (ref) async => [
        (
          attacker: 'Очень_Длинный_Ник_01',
          attackerId: 'f1',
          attackerWon: true,
          at: DateTime.now(),
        ),
        (
          attacker: 'Кирпич',
          attackerId: null,
          attackerWon: false,
          at: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
    ),
    notificationsProvider.overrideWith(
      (ref) async => (
        unread: 12,
        items: [
          for (var i = 0; i < 6; i++)
            AppNotification(
              id: 'n$i',
              type: const [
                'friend_request',
                'attacked',
                'streak_risk',
                'friend_accepted',
              ][i % 4],
              title: 'Очень длинный заголовок уведомления номер $i',
              body: 'Очень_Длинный_Ник_01 напал на тебя, но твой герой выстоял. Вызови в ответ!',
              screen: 'duels',
              read: i > 2,
              createdAt: DateTime.now().subtract(Duration(hours: i * 7)),
            ),
        ],
      ),
    ),
  ];
}

/// Подготовка особых состояний экранов: идёт тренировка, итог, бой.
Future<void> _prepare(ProviderContainer c, String path) async {
  switch (path) {
    case '/workout':
      final w = c.read(workoutProvider.notifier)..start();
      for (final e in ExerciseCatalog.all.take(3)) {
        w.addExercise(e);
      }
    case '/workout/stats':
      final log = c.read(trainingLogProvider.notifier);
      for (var i = 40; i >= 0; i -= 3) {
        await log.add(
          LoggedWorkout(
            at: DateTime.now().subtract(Duration(days: i)),
            kind: i % 2 == 0 ? WorkoutKind.strength : WorkoutKind.cardio,
            duration: const Duration(minutes: 52),
            xp: 400,
            coins: 80,
            verified: true,
            exercises: [
              for (final e in ExerciseCatalog.all.take(4))
                (
                  id: e.id,
                  sets: [
                    for (var k = 0; k < 4; k++)
                      SetRecord(weight: 60.0 + 40 - i, reps: 10),
                  ],
                ),
            ],
            gains: {for (final p in BodyPart.values) p: 60},
          ),
        );
      }
    case '/workout/result':
      final s = c.read(heroProvider)!;
      var entry = ExerciseEntry(exercise: ExerciseCatalog.all.first);
      for (var i = 0; i < 4; i++) {
        entry = entry.withSet(const SetRecord(weight: 60, reps: 10));
      }
      c
          .read(lastSummaryProvider.notifier)
          .show(
            WorkoutScoring.summarize(
              session: WorkoutSession(
                startedAt: DateTime.now().subtract(const Duration(minutes: 55)),
                entries: [entry],
              ),
              xpBefore: s.xp,
              validity: 0.5,
              finishedAt: DateTime.now(),
            ),
          );
    case '/duels/fight':
      c
          .read(fightProvider.notifier)
          .show(
            FightView(
              id: 'f',
              friend: false,
              attacker: _fighter('me', _longNick, 9),
              defender: _fighter('b', 'Очень_Длинный_Ник_01', 9),
              powerA: 560,
              powerD: 560,
              hpA: 300,
              hpD: 420,
              round: 2,
              rules: const CombatRules(),
            ),
          );
    case '/duels/battle':
      c
          .read(currentDuelProvider.notifier)
          .show(
            DuelSimulator.fight(
              _fighter('me', _longNick, 9),
              _fighter('b', 'Очень_Длинный_Ник_01', 9),
              7,
            ),
          );
  }
}

class _Problem {
  _Problem(this.where, this.what);
  final String where;
  final String what;
  @override
  String toString() => '• $where\n    $what';
}

/// Превью экранов для проверки дизайна глазами (не сравниваются в обычном прогоне).
const _preview = bool.fromEnvironment('PREVIEW');

Future<void> _loadFont(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    final b = File(f).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
}

/// Настоящие шрифты для превью: Inter, Russo One, иконки Lucide и Material.
Future<void> _loadPreviewFonts() async {
  await _loadFont('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
  ]);
  await _loadFont('Roboto', ['assets/fonts/Inter-Regular.ttf']);
  await _loadFont('RussoOne', ['assets/fonts/RussoOne-Regular.ttf']);
  final cache =
      Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['LOCALAPPDATA']}/Pub/Cache';
  final pkg =
      Directory('$cache/hosted/pub.dev')
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.contains('lucide_icons_flutter'))
          .map((d) => d.path)
          .toList()
        ..sort();
  final lucide = Directory('${pkg.last}/assets')
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere((f) => f.path.endsWith('.ttf'))
      .path;
  await _loadFont('packages/lucide_icons_flutter/Lucide', [lucide]);
  await _loadFont('MaterialIcons', [
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
}

Future<void> _audit(
  WidgetTester tester, {
  required bool signedIn,
  required List<String> routes,
  required List<_Problem> problems,
}) async {
  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      // Крупный шрифт проверяем на типичном экране — так делает большинство людей.
      if (scale != 1.0 && size != _typical) continue;
      for (final path in routes) {
        final where =
            '${signedIn ? 'аккаунт' : 'офлайн'} · $path · $sizeName${scale == 1.0 ? '' : ' · шрифт ×${scale.toString().replaceAll('.', ',')}'}';
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;

        // Онбординг открывается только у нового игрока — без героя.
        SharedPreferences.setMockInitialValues(
          path == '/onboarding'
              ? {}
              : {
                  'hero_v1': _hero().encode(),
                  // Без ответа на главной всплывает вопрос о пульсе — он проверяется отдельно.
                  'health_consent_v1': '{"granted":true}',
                  // Превью — без обучающих подсказок поверх экрана.
                  if (_preview) ...{
                    for (final t in [
                      'home',
                      'workout',
                      'duels',
                      'rating',
                      'profile',
                    ])
                      'guide_done_$t': true,
                    for (final id in screenHints.keys) 'hint_seen_$id': true,
                  },
                },
        );
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            if (signedIn) ..._serverFakes(),
          ],
        );
        await _prepare(container, path);

        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          final text = d.exceptionAsString();
          // Шрифты Google в тестах не скачиваются — это не ошибка вёрстки.
          if (!text.contains('google_fonts') && !text.contains('GoogleFonts')) {
            // Где именно: «The relevant error-causing widget was: Column lib/screens/…:123».
            final m = RegExp(
              r'error-causing widget was:\s+(\w+)[\s\S]*?(lib[/\\][^\s:]+:\d+)',
            ).firstMatch(d.toString());
            errors.add(
              '${text.split('\n').first}${m == null ? '' : '  ← ${m.group(1)} ${m.group(2)}'}',
            );
            // flutter test --dart-define=UI_AUDIT_VERBOSE=true — полный текст ошибок без места.
            if (m == null && const bool.fromEnvironment('UI_AUDIT_VERBOSE')) {
              debugPrint('=== ПОЛНОСТЬЮ ===\n$d');
            }
          }
        };
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const IronRiseApp(),
            ),
          );
          container.read(routerProvider).go(path);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          // Бой — сразу к итогу: панель с разбором и реваншем занимает больше всего места.
          if (path == '/duels/battle') {
            await tester.tap(find.text('Пропустить').first);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
          }

          if (_preview && scale == 1.0 && size == _typical) {
            // Дать доиграть анимациям появления (карточки входят с задержкой).
            for (var i = 0; i < 10; i++) {
              await tester.pump(const Duration(milliseconds: 150));
            }
            final name =
                '${signedIn ? 'acc' : 'off'}${path == '/' ? '_home' : path.replaceAll('/', '_')}';
            await expectLater(
              find.byType(IronRiseApp),
              matchesGoldenFile('preview/$name.png'),
            );
          }

          // «Без прокрутки» — на обычном и большом телефоне с обычным шрифтом. На маленьком
          // экране и с крупным шрифтом прокрутка — запасной вариант вместо наложения (FitScreen).
          final strict = scale == 1.0 && _strictSizes.contains(size);
          if (strict && _noScrollTabs.contains(path)) {
            for (final s in tester.stateList<ScrollableState>(
              find.byType(Scrollable),
            )) {
              final pos = s.position;
              final vertical = pos.axis == Axis.vertical;
              // Внутренний список друзей прокручивается по замыслу — их может быть много.
              final inner = find
                  .ancestor(
                    of: find.byWidget(s.widget),
                    matching: find.byType(ListView),
                  )
                  .evaluate()
                  .isNotEmpty;
              if (vertical &&
                  pos.maxScrollExtent > 0.5 &&
                  !(path == '/duels' && inner)) {
                errors.add(
                  'нужна прокрутка на ${pos.maxScrollExtent.round()} dp — вкладка не помещается в экран',
                );
              }
            }
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(
            const Duration(seconds: 2),
          ); // догорают таймеры анимаций
          FlutterError.onError = previous;
          container.dispose();
        }
        for (final e in errors.toSet()) {
          problems.add(_Problem(where, e));
        }
      }
    }
  }
}

void main() {
  if (_preview) setUpAll(_loadPreviewFonts);
  tearDown(() {
    debugPaintSizeEnabled = false;
  });

  testWidgets('все экраны без ошибок отображения', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final problems = <_Problem>[];

    await _audit(
      tester,
      signedIn: false,
      problems: problems,
      routes: const [
        '/',
        '/wardrobe',
        '/shop',
        '/shop/premium',
        '/tip',
        '/workout',
        '/workout/result',
        '/workout/exercises',
        '/workout/stats',
        '/season',
        '/duels/auras',
        '/workout/cardio',
        '/workout/joint',
        '/duels',
        '/duels/battle',
        '/rating',
        '/profile',
        '/profile/settings',
        '/profile/settings/schedule',
        '/profile/heart-rate',
        '/profile/devices',
        '/profile/account',
        '/profile/friends',
        '/profile/health',
        '/profile/start-look',
        '/privacy',
        '/onboarding',
      ],
    );
    await _audit(
      tester,
      signedIn: true,
      problems: problems,
      routes: const [
        '/',
        '/duels',
        '/duels/friends',
        '/duels/fight',
        '/rating',
        '/season',
        '/duels/auras',
        '/duels/auras/fury',
        '/notifications',
        '/profile',
        '/profile/account',
        '/workout/joint',
      ],
    );

    expect(
      problems,
      isEmpty,
      reason:
          '\nОшибки отображения (${problems.length}):\n${problems.join('\n')}',
    );
  });

  testWidgets('переключение вкладок с анимацией — без ошибок', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'hero_v1': _hero().encode(),
      'health_consent_v1': '{"granted":true}',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const IronRiseApp(),
      ),
    );
    await tester.pump();
    // Быстро прыгаем по вкладкам, не дожидаясь конца анимаций, и возвращаемся.
    for (final path in [
      '/duels',
      '/rating',
      '/profile',
      '/workout',
      '/',
      '/duels',
      '/',
    ]) {
      container.read(routerProvider).go(path);
      await tester.pump(const Duration(milliseconds: 90));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text(_longNick), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}

/// Ауры для экрана: одна открыта и выбрана, лимит недели почти исчерпан.
class _Auras extends AuraNotifier {
  @override
  Future<AuraInfo> build() async => AuraInfo.fromJson({
    'equipped': 'fury',
    'sessionsThisWeek': 1,
    'perWeek': 2,
    'auras': [
      {'kind': 'fury', 'sessions': 4, 'level': 2, 'toNext': 2},
      {'kind': 'guard', 'sessions': 0, 'level': 0, 'toNext': 1},
      {'kind': 'haste', 'sessions': 15, 'level': 5, 'toNext': null},
      {'kind': 'focus', 'sessions': 1, 'level': 1, 'toNext': 2},
    ],
  });
}
