import 'dart:convert';

import '../game/body_part.dart';
import '../game/progression.dart';
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
  const BodyStats({this.sex, this.heightCm, this.weightKg, this.experience});

  final Sex? sex;
  final int? heightCm;
  final double? weightKg;
  final Experience? experience;

  Map<String, dynamic> toJson() => {
        'sex': sex?.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'experience': experience?.name,
      };

  factory BodyStats.fromJson(Map<String, dynamic> j) => BodyStats(
        sex: j['sex'] == null ? null : Sex.values.byName(j['sex']),
        heightCm: j['heightCm'],
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        experience:
            j['experience'] == null ? null : Experience.values.byName(j['experience']),
      );
}

class HeroProfile {
  const HeroProfile({
    required this.nickname,
    required this.goal,
    required this.format,
    required this.trainingDays,
    required this.body,
    required this.xp,
    required this.streakDays,
  });

  factory HeroProfile.create({
    required String nickname,
    required Goal goal,
    required TrainingFormat format,
    required List<int> trainingDays,
    required BodyStats body,
  }) =>
      HeroProfile(
        nickname: nickname,
        goal: goal,
        format: format,
        trainingDays: trainingDays,
        body: body,
        xp: {for (final p in BodyPart.values) p: 0},
        streakDays: 0,
      );

  final String nickname;
  final Goal goal;
  final TrainingFormat format;
  final List<int> trainingDays;
  final BodyStats body;
  final Map<BodyPart, int> xp;
  final int streakDays;

  Map<BodyPart, int> get levels => Progression.levels(xp);
  List<BodyPart> get lagging => Progression.laggingParts(levels);
  int get power => Progression.power(levels, streakDays);
  int get maxRestDays => maxRestDaysInRow(trainingDays);

  HeroProfile copyWith({Map<BodyPart, int>? xp, int? streakDays}) => HeroProfile(
        nickname: nickname,
        goal: goal,
        format: format,
        trainingDays: trainingDays,
        body: body,
        xp: xp ?? this.xp,
        streakDays: streakDays ?? this.streakDays,
      );

  String encode() => jsonEncode({
        'nickname': nickname,
        'goal': goal.name,
        'format': format.name,
        'trainingDays': trainingDays,
        'body': body.toJson(),
        'xp': {for (final e in xp.entries) e.key.name: e.value},
        'streakDays': streakDays,
      });

  factory HeroProfile.decode(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    final xpJson = j['xp'] as Map<String, dynamic>;
    return HeroProfile(
      nickname: j['nickname'],
      goal: Goal.values.byName(j['goal']),
      format: TrainingFormat.values.byName(j['format']),
      trainingDays: List<int>.from(j['trainingDays']),
      body: BodyStats.fromJson(j['body']),
      xp: {for (final p in BodyPart.values) p: (xpJson[p.name] as int?) ?? 0},
      streakDays: j['streakDays'] ?? 0,
    );
  }
}
