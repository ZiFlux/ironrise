import 'dart:convert';

import '../avatar/avatar_look.dart';
import '../game/body_part.dart';
import '../game/calendar.dart';
import '../game/game_config.dart';
import '../game/progression.dart';
import '../game/streak.dart';
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
  regular('Тренируюсь регулярно');

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
  });

  final Sex? sex;
  final int? heightCm;
  final double? weightKg;
  final Experience? experience;

  /// Для максимального пульса (220 − возраст) и пульсовых зон.
  final int? age;
  final int? restingHeartRate;

  BodyStats copyWith({int? age, int? restingHeartRate}) => BodyStats(
    sex: sex,
    heightCm: heightCm,
    weightKg: weightKg,
    experience: experience,
    age: age ?? this.age,
    restingHeartRate: restingHeartRate ?? this.restingHeartRate,
  );

  Map<String, dynamic> toJson() => {
    'sex': sex?.name,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'experience': experience?.name,
    'age': age,
    'restingHeartRate': restingHeartRate,
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
  );
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
    this.coins = 0,
    this.lastActiveDay,
    this.activeDays = const {},
    this.ownedItems = const {},
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
  );

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

  /// Купленная косметика (id из ShopCatalog). Бесплатные вещи сюда не пишутся.
  final Set<String> ownedItems;

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
    Map<BodyPart, int>? xp,
    int? streakDays,
    AvatarLook? look,
    BodyStats? body,
    int? coins,
    DateTime? lastActiveDay,
    Set<String>? activeDays,
    Set<String>? ownedItems,
    TrainingFormat? format,
    List<int>? trainingDays,
    DateTime? nextScheduleChangeAt,
    bool scheduleChangeAllowed = false,
  }) => HeroProfile(
    nickname: nickname,
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
    createdAt: createdAt,
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
    'ownedItems': ownedItems.toList()..sort(),
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
      look: j['look'] == null
          ? AvatarLook.starter(AvatarSex.male)
          : AvatarLook.fromJson(j['look']),
      xp: {for (final p in BodyPart.values) p: (xpJson[p.name] as int?) ?? 0},
      streakDays: j['streakDays'] ?? 0,
      coins: j['coins'] ?? 0,
      lastActiveDay: lastActive,
      activeDays: activeDays,
      ownedItems: Set<String>.from(j['ownedItems'] ?? const []),
      createdAt: createdRaw == null
          ? lastActive ?? DateTime.now()
          : DateTime.parse(createdRaw),
      nextScheduleChangeAt: j['nextScheduleChangeAt'] == null
          ? null
          : DateTime.parse(j['nextScheduleChangeAt'] as String),
    );
  }
}
