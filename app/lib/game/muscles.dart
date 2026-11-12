import 'dart:math';

import 'body_part.dart';

/// Отдельные мышцы аватара. Опыт копится по частям тела (ТЗ 4.1), а очки мышц
/// показывают, как он распределён внутри части: кто качает одно и то же,
/// получает перекачанную мышцу. Совпадает с server/src/game/muscles.ts.
enum Muscle {
  pecs('Грудные', BodyPart.chest),
  delts('Дельты', BodyPart.arms),
  biceps('Бицепс', BodyPart.arms),
  triceps('Трицепс', BodyPart.arms),
  forearms('Предплечья', BodyPart.arms),
  lats('Широчайшие', BodyPart.back),
  traps('Трапеции', BodyPart.back),
  lowerBack('Поясница', BodyPart.back),
  abs('Пресс', BodyPart.core),
  obliques('Косые', BodyPart.core),
  quads('Квадрицепс', BodyPart.legs),
  hamstrings('Бицепс бедра', BodyPart.legs),
  glutes('Ягодицы', BodyPart.legs),
  calves('Икры', BodyPart.legs);

  const Muscle(this.label, this.part);
  final String label;
  final BodyPart part;
}

typedef MusclePoints = Map<Muscle, double>;

/// Целевые мышцы упражнений, доли в сумме 1.
const exerciseMuscles = <String, Map<Muscle, double>>{
  'push_up': {
    Muscle.pecs: 0.55,
    Muscle.triceps: 0.2,
    Muscle.delts: 0.15,
    Muscle.abs: 0.1,
  },
  'bench_press': {Muscle.pecs: 0.6, Muscle.triceps: 0.25, Muscle.delts: 0.15},
  'db_bench_press': {Muscle.pecs: 0.6, Muscle.triceps: 0.2, Muscle.delts: 0.2},
  'dips': {Muscle.triceps: 0.45, Muscle.pecs: 0.4, Muscle.delts: 0.15},
  'lat_pulldown': {Muscle.lats: 0.6, Muscle.biceps: 0.25, Muscle.traps: 0.15},
  'db_row': {
    Muscle.lats: 0.5,
    Muscle.traps: 0.2,
    Muscle.biceps: 0.2,
    Muscle.forearms: 0.1,
  },
  'pull_up': {
    Muscle.lats: 0.55,
    Muscle.biceps: 0.25,
    Muscle.traps: 0.1,
    Muscle.forearms: 0.1,
  },
  'back_extension': {
    Muscle.lowerBack: 0.6,
    Muscle.glutes: 0.25,
    Muscle.hamstrings: 0.15,
  },
  'bodyweight_squat': {Muscle.quads: 0.6, Muscle.glutes: 0.3, Muscle.abs: 0.1},
  'barbell_squat': {
    Muscle.quads: 0.55,
    Muscle.glutes: 0.25,
    Muscle.lowerBack: 0.1,
    Muscle.abs: 0.1,
  },
  'lunges': {
    Muscle.quads: 0.45,
    Muscle.glutes: 0.35,
    Muscle.hamstrings: 0.1,
    Muscle.calves: 0.1,
  },
  'leg_press': {Muscle.quads: 0.65, Muscle.glutes: 0.25, Muscle.calves: 0.1},
  'romanian_deadlift': {
    Muscle.hamstrings: 0.45,
    Muscle.glutes: 0.3,
    Muscle.lowerBack: 0.25,
  },
  'db_shoulder_press': {
    Muscle.delts: 0.65,
    Muscle.triceps: 0.25,
    Muscle.traps: 0.1,
  },
  'db_curl': {Muscle.biceps: 0.8, Muscle.forearms: 0.2},
  'french_press': {Muscle.triceps: 1},
  'plank': {Muscle.abs: 0.7, Muscle.obliques: 0.3},
  'crunches': {Muscle.abs: 0.85, Muscle.obliques: 0.15},
  'hanging_leg_raise': {
    Muscle.abs: 0.65,
    Muscle.obliques: 0.2,
    Muscle.forearms: 0.15,
  },
};

class MuscleMath {
  const MuscleMath._();

  /// Очки за тренировку: подходы × доля мышцы × достоверность.
  static MusclePoints pointsOf(
    Iterable<({String exerciseId, int sets})> entries,
    double validity,
  ) {
    final out = <Muscle, double>{};
    for (final e in entries) {
      for (final MapEntry(key: m, value: share)
          in (exerciseMuscles[e.exerciseId] ?? const {}).entries) {
        out[m] = (out[m] ?? 0) + e.sets * share * validity;
      }
    }
    return out;
  }

  static MusclePoints add(MusclePoints a, MusclePoints b) => {
    for (final m in Muscle.values)
      if (a.containsKey(m) || b.containsKey(m))
        m: (((a[m] ?? 0) + (b[m] ?? 0)) * 100).roundToDouble() / 100,
  };

  static MusclePoints fromJson(Map<String, dynamic>? j) => {
    if (j != null)
      for (final m in Muscle.values)
        if (j[m.name] is num) m: (j[m.name] as num).toDouble(),
  };

  static Map<String, double> toJson(MusclePoints p) => {
    for (final e in p.entries) e.key.name: e.value,
  };

  /// Доля мышцы внутри своей части при «ровной» программе — среднее по справочнику.
  static final Map<Muscle, double> _reference = () {
    final sum = <Muscle, double>{};
    for (final shares in exerciseMuscles.values) {
      for (final e in shares.entries) {
        sum[e.key] = (sum[e.key] ?? 0) + e.value;
      }
    }
    final byPart = <BodyPart, double>{};
    for (final e in sum.entries) {
      byPart[e.key.part] = (byPart[e.key.part] ?? 0) + e.value;
    }
    return {for (final e in sum.entries) e.key: e.value / byPart[e.key.part]!};
  }();

  /// Сколько очков нужно, чтобы пропорции стали заметны (≈ две-три тренировки части).
  static const _confidentPoints = 30.0;

  /// Множитель роста каждой мышцы: 1 — как у всех, больше — перекачана, меньше — отстаёт.
  static Map<Muscle, double> balance(MusclePoints points) {
    final perPart = <BodyPart, double>{};
    for (final e in points.entries) {
      perPart[e.key.part] = (perPart[e.key.part] ?? 0) + e.value;
    }
    return {
      for (final m in Muscle.values)
        m: () {
          final total = perPart[m.part] ?? 0;
          if (total <= 0) return 1.0;
          final ratio = ((points[m] ?? 0) / total) / _reference[m]!;
          final raw = sqrt(ratio).clamp(0.7, 1.4);
          final weight = min(1.0, total / _confidentPoints);
          return 1 + (raw - 1) * weight;
        }(),
    };
  }

  /// Гротескная мышца — шуточный бонус: одна мышца забрала больше трети всех очков
  /// и вдвое обгоняет «ровную» программу. null — тело развивается ровно.
  static Muscle? grotesque(MusclePoints points) {
    final total = points.values.fold<double>(0, (a, b) => a + b);
    if (total < 40) return null;
    final globalRef = <Muscle, double>{};
    var refTotal = 0.0;
    for (final shares in exerciseMuscles.values) {
      for (final e in shares.entries) {
        globalRef[e.key] = (globalRef[e.key] ?? 0) + e.value;
        refTotal += e.value;
      }
    }
    Muscle? best;
    var bestRatio = 0.0;
    for (final e in points.entries) {
      final share = e.value / total;
      final ratio = share / (globalRef[e.key]! / refTotal);
      if (share >= 0.3 && ratio >= 2.2 && ratio > bestRatio) {
        best = e.key;
        bestRatio = ratio;
      }
    }
    return best;
  }

  /// Насколько раздута гротескная мышца на аватаре: прибавка к росту 0…1.
  static const grotesqueBoost = 0.8;
}

/// Подпись к гротескной мышце — шутка с подсказкой, что ещё покачать.
String grotesqueJoke(Muscle m) => switch (m) {
  Muscle.pecs => 'Грудь-гигант: видно, кто в понедельник первым занимает скамью. Ноги тоже ждут.',
  Muscle.biceps =>
    'Бицепсы-банки: зеркало в зале уже узнаёт тебя. Спина и ноги обижаются.',
  Muscle.triceps => 'Трицепс-подкова: руки как у кузнеца. Добавь тяги, чтобы спина не отставала.',
  Muscle.delts =>
    'Плечи-ядра: в дверь скоро будешь входить боком. Не забудь про ноги.',
  Muscle.lats =>
    'Крылья: ещё пара тяг — и полетишь. Грудь и ноги просят внимания.',
  Muscle.quads =>
    'Ноги-колонны: день ног — каждый день? Верх тела тоже хочет расти.',
  Muscle.glutes =>
    'Ягодицы-орехи: штаны трещат по швам. Добавь жимов для верха.',
  Muscle.abs =>
    'Пресс-стиральная доска: можно стирать бельё. Остальное тоже покачай.',
  _ =>
    '${m.label} растут быстрее всего остального. Разнообразь тренировки — или носи с гордостью.',
};
