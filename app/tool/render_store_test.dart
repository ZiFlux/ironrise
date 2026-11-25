// Скриншоты для RuStore: настоящие экраны приложения с демо-данными, снятые
// в разрешении телефона (×3), и рекламные кадры 1080×1920 с заголовком.
// Не входит в обычные тесты (лежит в tool/).
//
// Запуск из app/:
//   flutter test tool/render_store_test.dart --dart-define=OUT=<папка> --dart-define=ENV=beta
// (ENV=beta — без метки DEV в углу).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/combat.dart';
import 'package:ironrise/game/duel.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/league.dart';
import 'package:ironrise/game/muscles.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/game/workout.dart';
import 'package:ironrise/main.dart';
import 'package:ironrise/router.dart';
import 'package:ironrise/state/account_state.dart';
import 'package:ironrise/state/aura_state.dart';
import 'package:ironrise/state/fight_state.dart';
import 'package:ironrise/state/hero.dart';
import 'package:ironrise/state/joint_state.dart';
import 'package:ironrise/state/providers.dart';
import 'package:ironrise/state/season_state.dart';
import 'package:ironrise/state/server_game.dart';
import 'package:ironrise/state/training_log.dart';
import 'package:ironrise/state/workout_state.dart';
import 'package:ironrise/widgets/screen_hint.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _out = String.fromEnvironment('OUT');

/// Кадр магазина: экран, заголовок и подпись.
typedef _Shot = ({String route, String file, String title, String subtitle});

const _shots = <_Shot>[
  (
    route: '/',
    file: '01_герой',
    title: 'Тренируйся —\nгерой растёт',
    subtitle: 'Каждый подход качает свою мышцу',
  ),
  (
    route: '/workout',
    file: '02_тренировка',
    title: 'Тренировка\nпо плану',
    subtitle: 'Упражнения, веса и отдых уже подставлены',
  ),
  (
    route: '/duels/fight',
    file: '03_бой',
    title: 'Бой с выбором\nдействий',
    subtitle: 'Удар, блок или захват — решаешь ты',
  ),
  (
    route: '/duels',
    file: '04_лестница',
    title: 'Лестница\nс боссами',
    subtitle: '13 ступеней от двора до Вершины',
  ),
  (
    route: '/rating',
    file: '05_лиги',
    title: 'Лиги с живыми\nигроками',
    subtitle: 'Сильная неделя — лига выше, до Чемпионской',
  ),
  (
    route: '/duels/auras',
    file: '06_ауры',
    title: 'Ауры\nдля дуэлей',
    subtitle: 'Растут короткими тренировками с пульсом',
  ),
  (
    route: '/workout/stats',
    file: '07_прогресс',
    title: 'Прогресс\nв цифрах',
    subtitle: 'Нагрузка на каждую мышцу и прогноз',
  ),
  (
    route: '/season',
    file: '08_сезон',
    title: 'Сезоны\nи награды',
    subtitle: '30 уровней: монеты, бустеры, одежда',
  ),
];

HeroProfile _hero() {
  final h = HeroProfile.create(
    nickname: 'Лис',
    goal: Goal.strength,
    format: TrainingFormat.fullBody,
    trainingDays: const [0, 2, 4],
    body: const BodyStats(),
    avatarSex: AvatarSex.male,
  );
  return h.copyWith(
    xp: {
      BodyPart.chest: 2380,
      BodyPart.back: 2210,
      BodyPart.arms: 2460,
      BodyPart.legs: 1980,
      BodyPart.core: 2100,
      BodyPart.cardio: 1650,
    },
    coins: 1840,
    muscles: MuscleMath.pointsOf([
      for (final e in ExerciseCatalog.all.take(14))
        (exerciseId: e.id, sets: 12),
    ], 1),
    streakDays: 24,
    lastActiveDay: DateTime.now(),
    look: AvatarLook.starter(AvatarSex.male).copyWith(skin: SkinTone.tan),
  );
}

Fighter _fighter(String id, String name, int level) => Fighter(
  id: id,
  name: name,
  levels: {for (final p in BodyPart.values) p: level},
  streakDays: 14,
);

class _SignedIn extends AccountNotifier {
  @override
  AccountState build() => const AccountState(email: 'lis@ironrise.ru');
}

class _NoJoint extends JointNotifier {
  @override
  Future<JointSession?> build() async => null;
}

class _Auras extends AuraNotifier {
  @override
  Stream<AuraInfo> build() => Stream.value(
    AuraInfo.fromJson({
      'equipped': 'fury',
      'sessionsThisWeek': 1,
      'perWeek': 2,
      'auras': [
        {'kind': 'fury', 'sessions': 9, 'level': 3, 'toNext': 2},
        {'kind': 'guard', 'sessions': 4, 'level': 2, 'toNext': 2},
        {'kind': 'haste', 'sessions': 15, 'level': 5, 'toNext': null},
        {'kind': 'focus', 'sessions': 1, 'level': 1, 'toNext': 2},
      ],
    }),
  );
}

List<Override> _server() {
  const names = [
    'Кирпич',
    'Ника_Сталь',
    'Медведь',
    'Тихий_Жим',
    'Айрон_Маша',
    'Гриф',
    'Лиса_Бег',
    'Штанга',
  ];
  return [
    accountProvider.overrideWith(_SignedIn.new),
    jointProvider.overrideWith(_NoJoint.new),
    serverBotsProvider.overrideWith(
      _stream(
        (ref) async => (
          ladder: (
            tier: 4,
            tiers: 13,
            name: 'Школьный стадион',
            bossId: 'boss',
            bossUnlocked: true,
            wins: 3,
            winsToBoss: 3,
            beaten: {'b0', 'b1', 'b2'},
            nextName: 'Спортзал района',
          ),
          bots: [
            _fighter('b0', 'Турникмен', 18),
            _fighter('b1', 'Брусья', 19),
            _fighter('b2', 'Скакалка', 20),
            _fighter('b3', 'Гантеля', 21),
            _fighter('boss', 'Тренер Михалыч', 24),
          ],
          results: {'b0': true, 'b1': true, 'b2': true},
          nextFightAt: <String, DateTime>{},
          fights: const {'b0': 1, 'b1': 1, 'b2': 2},
        ),
      ),
    ),
    serverFriendsProvider.overrideWith(
      _stream(
        (ref) async => (
          friends: [
            for (var i = 0; i < 6; i++) _fighter('f$i', names[i], 14 + i * 2),
          ],
          incoming: <({String userId, String nickname})>[],
          outgoing: <({String userId, String nickname})>[],
          results: {'f0': true},
          fightsLeft: 3,
        ),
      ),
    ),
    serverLeagueProvider.overrideWith(
      _stream(
        (ref) async => (
          entries: [
            for (var i = 0; i < 8; i++)
              LeagueEntry(
                name: i == 1 ? 'Лис' : names[i],
                points: 168 - i * 13,
                isPlayer: i == 1,
              ),
          ],
          trainedDays: 3,
          wins: 6,
          tier: LeagueTier.gold,
          promoteTop: 2,
          minDaysToPromote: 1,
          demoteBottom: 2,
          lastWeek: (rank: 1, outcome: 'up', tierBefore: 1, tierAfter: 2),
        ),
      ),
    ),
    auraProvider.overrideWith(_Auras.new),
    seasonProvider.overrideWith(
      _stream(
        (ref) async => SeasonInfo.fromJson({
          'number': 2,
          'name': 'Закалка',
          'endsAt': '2027-02-22T00:00:00Z',
          'points': 1890,
          'level': 12,
          'levelPoints': 150,
          'maxLevel': 30,
          'premium': false,
          'freeGranted': 12,
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
                  'items': [if (l == 13) 'hc_s1'],
                  'boosters': {'xp': 0, 'coins': 0},
                },
              },
          ],
        }),
      ),
    ),
    serverFriendsLeagueProvider.overrideWith(
      _stream(
        (ref) async => [
          for (var i = 0; i < 8; i++)
            LeagueEntry(name: names[i], points: 140 - i * 11, isPlayer: i == 2),
        ],
      ),
    ),
    serverAttacksProvider.overrideWith(
      _stream(
        (ref) async =>
            <
              ({
                String attacker,
                String? attackerId,
                bool attackerWon,
                DateTime at,
              })
            >[],
      ),
    ),
    notificationsProvider.overrideWith(
      _stream((ref) async => (unread: 0, items: <AppNotification>[])),
    ),
  ];
}

Future<void> _prepare(ProviderContainer c, String route) async {
  switch (route) {
    case '/workout':
      final w = c.read(workoutProvider.notifier)..start();
      for (final id in ['barbell_squat', 'bench_press', 'barbell_row']) {
        w.addExercise(ExerciseCatalog.all.firstWhere((e) => e.id == id));
      }
    case '/workout/stats':
      final log = c.read(trainingLogProvider.notifier);
      for (var i = 40; i >= 0; i -= 2) {
        await log.add(
          LoggedWorkout(
            at: DateTime.now().subtract(Duration(days: i)),
            kind: i % 6 == 0 ? WorkoutKind.cardio : WorkoutKind.strength,
            duration: const Duration(minutes: 48),
            xp: 420,
            coins: 84,
            verified: true,
            exercises: [
              for (final id
                  in (i ~/ 2).isEven
                      ? [
                          'barbell_squat',
                          'bench_press',
                          'barbell_row',
                          'overhead_press',
                          'db_curl',
                          'plank',
                        ]
                      : [
                          'deadlift',
                          'incline_db_press',
                          'lat_pulldown',
                          'lunges',
                          'triceps_pushdown',
                          'calf_raise',
                        ])
                (
                  id: id,
                  sets: [
                    for (var k = 0; k < 3; k++)
                      SetRecord(weight: 30.0 + (40 - i) * 0.4, reps: 10),
                  ],
                ),
            ],
            gains: {for (final p in BodyPart.values) p: 70},
          ),
        );
      }
    case '/duels/fight':
      c
          .read(fightProvider.notifier)
          .show(
            FightView(
              id: 'f',
              friend: false,
              attacker: _fighter('me', 'Лис', 22),
              defender: _fighter('boss', 'Тренер Михалыч', 24),
              powerA: 1420,
              powerD: 1510,
              hpA: 980,
              hpD: 760,
              round: 3,
              rules: const CombatRules(),
            ),
          );
  }
}

Future<void> _loadFont(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    final b = File(f).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
}

Future<void> _loadFonts() async {
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

/// Рекламный кадр: заголовок, подпись и экран в рамке телефона.
class _FramePainter extends CustomPainter {
  _FramePainter(this.screen);

  final ui.Image screen;

  static const _accent = Color(0xFFFF6B4A);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1418), Color(0xFF120D10)],
        ).createShader(rect),
    );
    // Тёплое свечение за телефоном.
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.68),
      size.width * 0.55,
      Paint()
        ..shader =
            RadialGradient(
              colors: [_accent.withValues(alpha: 0.28), Colors.transparent],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width / 2, size.height * 0.68),
                radius: size.width * 0.55,
              ),
            ),
    );
    // Телефон.
    const phoneH = 1360.0;
    final phoneW = phoneH * screen.width / screen.height;
    final phone = Rect.fromLTWH(
      (size.width - phoneW) / 2,
      size.height - phoneH - 70,
      phoneW,
      phoneH,
    );
    final r = RRect.fromRectAndRadius(
      phone.inflate(14),
      const Radius.circular(70),
    );
    canvas.drawRRect(
      r.shift(const Offset(0, 24)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFF0A0809));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF3A2C31),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(phone, const Radius.circular(58)));
    canvas.drawImageRect(
      screen,
      Offset.zero & Size(screen.width.toDouble(), screen.height.toDouble()),
      phone,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FramePainter old) => true;
}

void main() {
  if (_out.isEmpty) {
    test('OUT не задан — пропуск', () {});
    return;
  }
  setUpAll(_loadFonts);

  testWidgets('скриншоты RuStore', (tester) async {
    addTearDown(tester.view.reset);
    // Русская система — интерфейс на русском, как у основной аудитории.
    tester.platformDispatcher.localeTestValue = const Locale('ru', 'RU');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final appKey = GlobalKey();
    final frameKey = GlobalKey();
    Future<ui.Image> grab(GlobalKey key, double ratio) async {
      late ui.Image image;
      await tester.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        image = await b.toImage(pixelRatio: ratio);
      });
      return image;
    }

    Future<void> save(ui.Image image, String path) async {
      await tester.runAsync(() async {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final f = File('$_out/$path');
        f.parent.createSync(recursive: true);
        f.writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    for (final shot in _shots) {
      // Экран: логически 360×780, снимок ×3 — 1080×2340.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      SharedPreferences.setMockInitialValues({
        'hero_v1': _hero().encode(),
        'health_consent_v1': '{"granted":true}',
        'records_v1': '{"workouts":21,"sets":378,"best":{}}',
        for (final t in ['home', 'workout', 'duels', 'rating', 'profile'])
          'guide_done_$t': true,
        for (final id in screenHints.keys) 'hint_seen_$id': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs), ..._server()],
      );
      await _prepare(container, shot.route);
      await tester.pumpWidget(
        RepaintBoundary(
          key: appKey,
          child: UncontrolledProviderScope(
            container: container,
            child: const IronRiseApp(),
          ),
        ),
      );
      container.read(routerProvider).go(shot.route);
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      final screen = await grab(appKey, 3);
      await save(screen, 'экраны/${shot.file}.png');

      // Рекламный кадр 1080×1920.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: frameKey,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _FramePainter(screen)),
                  ),
                  Positioned(
                    left: 72,
                    right: 72,
                    top: 90,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shot.title,
                          style: const TextStyle(
                            fontFamily: 'RussoOne',
                            fontSize: 86,
                            height: 1.08,
                            color: Color(0xFFF3EAEC),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          shot.subtitle,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 40,
                            height: 1.3,
                            color: Color(0xFFB9A9AE),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await save(await grab(frameKey, 1), 'rustore/${shot.file}.png');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      container.dispose();
    }
  });
}

/// Данные вкладок приходят потоком (кэш, затем сервер): здесь — одно значение.
Stream<T> Function(Ref) _stream<T>(Future<T> Function(Ref) make) =>
    (ref) => Stream.fromFuture(make(ref));
