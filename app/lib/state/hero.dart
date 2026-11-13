import 'dart:convert';

import '../avatar/avatar_look.dart';
import '../game/muscles.dart';
import '../game/body_part.dart';
import '../game/calendar.dart';
import '../game/game_config.dart';
import '../game/progression.dart';
import '../game/streak.dart';
import '../game/streak_rewards.dart';
import '../game/training_format.dart';

enum Goal {
  mass('Набрать массу'),
  strength('Стать сильнее'),
  fatLoss('Похудеть'),
  consistency('Тренироваться регулярно');

  const Goal(this.label);
  final String label;
}

enum Sex {
  male('Мужской'),
  female('Женский');

  const Sex(this.label);
  final String label;
}

enum Experience {
  none('Никогда не тренировался'),
  some('Пробовал, бросал'),
  regular('Тренируюсь регулярно, до 2 лет'),
  advanced('Тренируюсь больше 2 лет');

  const Experience(this.label);
  final String label;
}

/// Данные о комплекции. Необязательны; понадобятся системе тренировок (PLAN.md, 4.6).
class BodyStats {
  const BodyStats({
    this.sex,
    this.heightCm,
    this.weightKg,
    this.experience,
    this.age,
    this.restingHeartRate,
    this.pushUps,
    this.pullUps,
  });

  /// Самопроверка в анкете: сколько раз отжимается и подтягивается за подход.
  /// Уточняет уровень подготовки (session_builder.dart).
  final int? pushUps;
  final int? pullUps;

  final Sex? sex;
  final int? heightCm;
  final double? weightKg;
  final Experience? experience;

  /// Для максимального пульса (220 − возраст) и пульсовых зон.
  final int? age;
  final int? restingHeartRate;

  BodyStats copyWith({
    double? weightKg,
    int? age,
    int? restingHeartRate,
    Experience? experience,
    int? pushUps,
    int? pullUps,
  }) => BodyStats(
    sex: sex,
    heightCm: heightCm,
    weightKg: weightKg ?? this.weightKg,
    experience: experience ?? this.experience,
    age: age ?? this.age,
    restingHeartRate: restingHeartRate ?? this.restingHeartRate,
    pushUps: pushUps ?? this.pushUps,
    pullUps: pullUps ?? this.pullUps,
  );

  Map<String, dynamic> toJson() => {
    'sex': sex?.name,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'experience': experience?.name,
    'age': age,
    'restingHeartRate': restingHeartRate,
    'pushUps': pushUps,
    'pullUps': pullUps,
  };

  factory BodyStats.fromJson(Map<String, dynamic> j) => BodyStats(
    sex: j['sex'] == null ? null : Sex.values.byName(j['sex']),
    heightCm: j['heightCm'],
    weightKg: (j['weightKg'] as num?)?.toDouble(),
    experience: j['experience'] == null
        ? null
        : Experience.values.byName(j['experience']),
    age: j['age'],
    restingHeartRate: j['restingHeartRate'],
    pushUps: j['pushUps'],
    pullUps: j['pullUps'],
  );
}

/// Премиум и статус бета-тестера — приходят с сервера (src/game/premium.ts).
class PremiumInfo {
  const PremiumInfo({
    this.active = false,
    this.source,
    this.until,
    this.isTester = false,
  });

  factory PremiumInfo.fromJson(Map<String, dynamic>? j) => j == null
      ? const PremiumInfo()
      : PremiumInfo(
          active: j['active'] == true,
          source: j['source'] as String?,
          until: j['until'] == null
              ? null
              : DateTime.parse(j['until'] as String).toLocal(),
          isTester: j['isTester'] == true,
        );

  final bool active;

  /// tester — навсегда у бета-тестеров; subscription — оплачен до [until].
  final String? source;
  final DateTime? until;
  final bool isTester;

  Map<String, dynamic> toJson() => {
    'active': active,
    'source': source,
    'until': until?.toUtc().toIso8601String(),
    'isTester': isTester,
  };
}

class HeroProfile {
  const HeroProfile({
    required this.nickname,
    required this.goal,
    required this.format,
    required this.trainingDays,
    required this.body,
    required this.look,
    required this.xp,
    required this.streakDays,
    required this.createdAt,
    this.nextScheduleChangeAt,
    this.nextNicknameChangeAt,
    this.coins = 0,
    this.lastActiveDay,
    this.activeDays = const {},
    this.ownedItems = const {},
    this.premium = const PremiumInfo(),
    this.startLook,
    this.startLookUntil,
    this.muscles = const {},
    this.boosters = const Boosters(),
  });

  factory HeroProfile.create({
    required String nickname,
    required Goal goal,
    required TrainingFormat format,
    required List<int> trainingDays,
    required BodyStats body,
    required AvatarSex avatarSex,
  }) => HeroProfile(
    nickname: nickname,
    goal: goal,
    format: format,
    trainingDays: trainingDays,
    body: body,
    look: AvatarLook.starter(avatarSex),
    xp: {for (final p in BodyPart.values) p: 0},
    streakDays: 0,
    createdAt: DateTime.now(),
    startLookUntil: DateTime.now().add(startLookWindow),
  );

  /// Сколько дней образ собирается бесплатно, прежде чем стать «Стартом».
  static const startLookWindow = Duration(days: 14);

  final String nickname;
  final Goal goal;
  final TrainingFormat format;
  final List<int> trainingDays;
  final BodyStats body;
  final AvatarLook look;
  final Map<BodyPart, int> xp;
  final int streakDays;
  final int coins;

  /// День последней тренировки, для подсчёта серии.
  final DateTime? lastActiveDay;

  /// Дни с тренировкой, ключи dayKey(). Для календаря недели.
  final Set<String> activeDays;

  final DateTime createdAt;

  /// Когда можно сменить график; null — уже можно (раз в 7 дней, PLAN 4.3).
  final DateTime? nextScheduleChangeAt;

  /// Когда можно бесплатно сменить ник; null — уже можно (game/nickname.dart).
  final DateTime? nextNicknameChangeAt;

  /// Купленная косметика (id из ShopCatalog). Бесплатные вещи сюда не пишутся.
  final Set<String> ownedItems;

  final PremiumInfo premium;

  /// Образ «Старт» на экране прогресса; null — ещё собирается.
  final AvatarLook? startLook;

  /// До этого момента образ собирается бесплатно; null — уже зафиксирован.
  final DateTime? startLookUntil;

  /// Очки отдельных мышц (MuscleMath): пропорции аватара и гротескная мышца.
  final MusclePoints muscles;

  /// Бустеры за серию на следующие тренировки (streak_rewards.dart).
  final Boosters boosters;

  /// Открыт ли редактор стартового образа.
  bool startLookOpen(DateTime now) =>
      startLook == null &&
      startLookUntil != null &&
      now.isBefore(startLookUntil!);

  /// Каким герой был в первый день: зафиксированный образ или тот, что собирается.
  AvatarLook get firstDayLook => startLook ?? look;

  /// V без часов: у бета-тестеров штрафа нет.
  double get unverifiedValidity =>
      premium.isTester ? 1 : GameConfig.unverifiedValidity;

  Map<BodyPart, int> get levels => Progression.levels(xp);

  /// Для аватара: растёт плавно с каждым подходом.
  Map<BodyPart, double> get avatarLevels => Progression.fractionalLevels(xp);

  int get restingHeartRate =>
      body.restingHeartRate ?? GameConfig.defaultRestingHeartRate;
  int get maxHeartRate =>
      body.age == null ? GameConfig.defaultMaxHeartRate : 220 - body.age!;
  List<BodyPart> get lagging => Progression.laggingParts(levels);
  int get power => Progression.power(levels, currentStreak(DateTime.now()));
  int get maxRestDays => maxRestDaysInRow(trainingDays);

  /// Серия с учётом сегодняшнего дня (сгорает после лишнего дня отдыха).
  int currentStreak(DateTime today) => Streak.current(
    streakDays: streakDays,
    lastActiveDay: lastActiveDay,
    today: today,
    maxRestDays: maxRestDays,
  );

  HeroProfile copyWith({
    String? nickname,
    DateTime? nextNicknameChangeAt,
    bool nicknameChangeAllowed = false,
    Map<BodyPart, int>? xp,
    int? streakDays,
    AvatarLook? look,
    BodyStats? body,
    int? coins,
    DateTime? lastActiveDay,
    Set<String>? activeDays,
    Set<String>? ownedItems,
    PremiumInfo? premium,
    TrainingFormat? format,
    List<int>? trainingDays,
    DateTime? nextScheduleChangeAt,
    bool scheduleChangeAllowed = false,
    AvatarLook? startLook,
    DateTime? startLookUntil,
    bool startLocked = false,
    MusclePoints? muscles,
    Boosters? boosters,
  }) => HeroProfile(
    nickname: nickname ?? this.nickname,
    nextNicknameChangeAt: nicknameChangeAllowed
        ? null
        : nextNicknameChangeAt ?? this.nextNicknameChangeAt,
    goal: goal,
    format: format ?? this.format,
    trainingDays: trainingDays ?? this.trainingDays,
    nextScheduleChangeAt: scheduleChangeAllowed
        ? null
        : nextScheduleChangeAt ?? this.nextScheduleChangeAt,
    body: body ?? this.body,
    look: look ?? this.look,
    xp: xp ?? this.xp,
    streakDays: streakDays ?? this.streakDays,
    coins: coins ?? this.coins,
    lastActiveDay: lastActiveDay ?? this.lastActiveDay,
    activeDays: activeDays ?? this.activeDays,
    ownedItems: ownedItems ?? this.ownedItems,
    premium: premium ?? this.premium,
    createdAt: createdAt,
    startLook: startLook ?? this.startLook,
    startLookUntil: startLocked ? null : startLookUntil ?? this.startLookUntil,
    muscles: muscles ?? this.muscles,
    boosters: boosters ?? this.boosters,
  );

  String encode() => jsonEncode({
    'nickname': nickname,
    'goal': goal.name,
    'format': format.name,
    'trainingDays': trainingDays,
    'body': body.toJson(),
    'look': look.toJson(),
    'xp': {for (final e in xp.entries) e.key.name: e.value},
    'streakDays': streakDays,
    'coins': coins,
    'lastActiveDay': lastActiveDay?.toIso8601String(),
    'activeDays': activeDays.toList()..sort(),
    'createdAt': createdAt.toIso8601String(),
    'nextScheduleChangeAt': nextScheduleChangeAt?.toIso8601String(),
    'nextNicknameChangeAt': nextNicknameChangeAt?.toIso8601String(),
    'ownedItems': ownedItems.toList()..sort(),
    'premium': premium.toJson(),
    'startLook': startLook?.toJson(),
    'startLookUntil': startLookUntil?.toIso8601String(),
    'muscles': MuscleMath.toJson(muscles),
    'boosters': boosters.toJson(),
  });

  factory HeroProfile.decode(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    final xpJson = j['xp'] as Map<String, dynamic>;
    final lastActiveRaw = j['lastActiveDay'] as String?;
    final lastActive = lastActiveRaw == null
        ? null
        : DateTime.parse(lastActiveRaw);
    // Старые сохранения: истории ещё не было, восстанавливаем что можем.
    final activeDays = j['activeDays'] == null
        ? {if (lastActive != null) dayKey(lastActive)}
        : Set<String>.from(j['activeDays']);
    final createdRaw = j['createdAt'] as String?;
    return HeroProfile(
      nickname: j['nickname'],
      goal: Goal.values.byName(j['goal']),
      format: TrainingFormat.values.byName(j['format']),
      trainingDays: List<int>.from(j['trainingDays']),
      body: BodyStats.fromJson(j['body']),
      // Старые сохранения без образа: только бесплатные вещи, редактор старта у них закрыт.
      look: j['look'] == null
          ? const AvatarLook(
              sex: AvatarSex.male,
              hair: HairStyle.short,
              top: TopKind.none,
            )
          : AvatarLook.fromJson(j['look']),
      xp: {for (final p in BodyPart.values) p: (xpJson[p.name] as int?) ?? 0},
      streakDays: j['streakDays'] ?? 0,
      coins: j['coins'] ?? 0,
      lastActiveDay: lastActive,
      activeDays: activeDays,
      ownedItems: Set<String>.from(j['ownedItems'] ?? const []),
      premium: PremiumInfo.fromJson(
        (j['premium'] as Map?)?.cast<String, dynamic>(),
      ),
      createdAt: createdRaw == null
          ? lastActive ?? DateTime.now()
          : DateTime.parse(createdRaw),
      nextScheduleChangeAt: j['nextScheduleChangeAt'] == null
          ? null
          : DateTime.parse(j['nextScheduleChangeAt'] as String),
      nextNicknameChangeAt: j['nextNicknameChangeAt'] == null
          ? null
          : DateTime.parse(j['nextNicknameChangeAt'] as String),
      boosters: Boosters.fromJson(
        (j['boosters'] as Map?)?.cast<String, dynamic>(),
      ),
      muscles: MuscleMath.fromJson(
        (j['muscles'] as Map?)?.cast<String, dynamic>(),
      ),
      startLook: j['startLook'] == null
          ? null
          : AvatarLook.fromJson(
              Map<String, dynamic>.from(j['startLook'] as Map),
            ),
      // Сохранения до этой функции: 14 дней с момента обновления.
      startLookUntil: j['startLook'] != null
          ? null
          : j['startLookUntil'] == null
          ? DateTime.now().add(startLookWindow)
          : DateTime.parse(j['startLookUntil'] as String),
    );
  }
}
