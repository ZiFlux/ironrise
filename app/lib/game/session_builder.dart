import 'body_part.dart';
import 'exercise_catalog.dart';
import 'muscles.dart';
import 'program.dart';

/// Уровень подготовки (п. 51–52 бэклога): сколько упражнений в тренировке,
/// какая недельная норма подходов на мышцу и с какой ступени лесенки начинать.
enum TrainingLevel {
  novice('Новичок', exercises: 6, weeklySets: 8, maxSets: 3, daySets: 16),
  intermediate(
    'Средний',
    exercises: 7,
    weeklySets: 12,
    maxSets: 4,
    daySets: 22,
  ),
  advanced('Опытный', exercises: 8, weeklySets: 16, maxSets: 4, daySets: 26);

  const TrainingLevel(
    this.label, {
    required this.exercises,
    required this.weeklySets,
    required this.maxSets,
    required this.daySets,
  });

  final String label;

  /// Упражнений в тренировке (6–8).
  final int exercises;

  /// Рабочих подходов в неделю на крупную мышцу (мелким — половина).
  final int weeklySets;

  /// Подходов в одном упражнении (не больше 4 — правило 20 бэклога).
  final int maxSets;

  /// Подходов за тренировку всего: дольше 70–80 минут тренировка не растягивается.
  final int daySets;

  /// Ступень лесенки «проще → сложнее» на старте.
  int get startStep => index + 1;
}

/// Мелкие мышцы: им хватает половины нормы — они работают и в базовых движениях.
const _smallMuscles = {
  Muscle.forearms,
  Muscle.calves,
  Muscle.obliques,
  Muscle.traps,
  Muscle.lowerBack,
};

/// Недельная норма подходов на мышцу для уровня.
double weeklyTarget(Muscle m, TrainingLevel level) =>
    level.weeklySets * (_smallMuscles.contains(m) ? 0.5 : 1);

/// Сколько «полных» подходов мышце даёт один подход упражнения: главная мышца
/// (доля от 0,5) — целый, помогающая — частично.
double setCredit(String exerciseId, Muscle m) {
  final share = exerciseMuscles[exerciseId]?[m] ?? 0;
  return share >= 0.5 ? 1 : share / 0.5;
}

/// Слот тренировки: движение и, если нужно, конкретные упражнения по предпочтению.
/// [priority] 1 — обязательно, 3 — если влезает по числу упражнений.
class _Slot {
  const _Slot(this.pattern, this.priority, [this.prefer = const []]);

  final String pattern;
  final int priority;
  final List<String> prefer;

  bool get compound => const {
    'squat',
    'hinge',
    'lunge',
    'push_h',
    'push_v',
    'pull_h',
    'pull_v',
  }.contains(pattern);
}

class _DayTemplate {
  const _DayTemplate(this.id, this.title, this.slots);

  final String id;
  final String title;
  final List<_Slot> slots;
}

/// Шаблоны дней. Сначала базовые движения, потом изоляция и пресс.
/// Базовые движения: варианты от самого продуктивного к самому простому —
/// берётся первый не сложнее ступени человека.
const _squat = [
  'barbell_squat',
  'goblet_squat',
  'leg_press',
  'bodyweight_squat',
];
const _bench = [
  'bench_press',
  'db_bench_press',
  'push_up',
  'machine_chest_press',
  'incline_push_up',
  'knee_push_up',
];
const _pullV = ['pull_up', 'negative_pull_up', 'lat_pulldown'];
const _pullH = ['barbell_row', 'seated_cable_row', 'db_row'];
const _press = ['overhead_press', 'db_shoulder_press'];
const _abs = ['hanging_leg_raise', 'crunches', 'plank', 'dead_bug'];

const _fullBodyA = _DayTemplate('A', 'Всё тело А', [
  _Slot('squat', 1, _squat),
  _Slot('push_h', 1, _bench),
  _Slot('pull_v', 1, _pullV),
  _Slot('hinge', 1, ['romanian_deadlift', 'glute_bridge']),
  _Slot('push_v', 2, _press),
  _Slot('core', 2, _abs),
  _Slot('biceps', 3),
  _Slot('triceps', 3),
]);

const _fullBodyB = _DayTemplate('B', 'Всё тело Б', [
  _Slot('hinge', 1, ['deadlift', 'romanian_deadlift', 'glute_bridge']),
  _Slot('push_h', 1, ['db_bench_press', 'push_up', 'machine_chest_press']),
  _Slot('pull_h', 1, _pullH),
  _Slot('lunge', 1),
  _Slot('delts', 2),
  _Slot('core', 2, ['side_plank', 'russian_twist', 'dead_bug']),
  _Slot('rear_delts', 3),
  _Slot('calves', 3),
]);

const _upper = _DayTemplate('U', 'Верх', [
  _Slot('push_h', 1, _bench),
  _Slot('pull_v', 1, _pullV),
  _Slot('push_v', 1, _press),
  _Slot('pull_h', 1, _pullH),
  _Slot('delts', 2),
  _Slot('biceps', 2),
  _Slot('triceps', 2),
  _Slot('rear_delts', 3),
]);

const _lower = _DayTemplate('L', 'Низ', [
  _Slot('squat', 1, _squat),
  _Slot('hinge', 1, ['deadlift', 'romanian_deadlift', 'glute_bridge']),
  _Slot('lunge', 1),
  _Slot('core', 1, _abs),
  _Slot('hinge', 2, ['leg_curl', 'glute_bridge', 'back_extension']),
  _Slot('quads', 2),
  _Slot('calves', 2),
  _Slot('core', 3, ['side_plank', 'russian_twist']),
]);

/// Сплит (п. 41): спина и бицепс; грудь, трицепс, предплечья; ноги и плечи.
const _splitBack = _DayTemplate('S1', 'Спина и бицепс', [
  _Slot('pull_v', 1, _pullV),
  _Slot('pull_h', 1, _pullH),
  _Slot('biceps', 1),
  _Slot('pull_h', 2, ['seated_cable_row', 'db_row']),
  _Slot('hinge', 2, ['back_extension', 'romanian_deadlift']),
  _Slot('biceps', 2, ['hammer_curl', 'barbell_curl', 'db_curl']),
  _Slot('rear_delts', 3),
  _Slot('core', 3),
]);

const _splitChest = _DayTemplate('S2', 'Грудь, трицепс, предплечья', [
  _Slot('push_h', 1, _bench),
  _Slot('push_h', 1, ['db_bench_press', 'machine_chest_press', 'push_up']),
  _Slot('triceps', 1),
  _Slot('triceps', 2, ['french_press', 'triceps_pushdown', 'bench_dips']),
  _Slot('biceps', 2, ['hammer_curl']),
  _Slot('delts', 2),
  _Slot('core', 3),
  _Slot('push_h', 3, ['dips', 'push_up', 'incline_push_up']),
]);

const _splitLegs = _DayTemplate('S3', 'Ноги и плечи', [
  _Slot('squat', 1, _squat),
  _Slot('hinge', 1, ['romanian_deadlift', 'deadlift', 'glute_bridge']),
  _Slot('push_v', 1, _press),
  _Slot('lunge', 2),
  _Slot('delts', 2),
  _Slot('hinge', 2, ['leg_curl', 'glute_bridge']),
  _Slot('calves', 2),
  _Slot('quads', 3),
]);

/// День отстающей части: всё тело, а слоты отстающей части выходят вперёд.
const _focus = _DayTemplate('F', 'День отстающей части', [
  _Slot('squat', 2, _squat),
  _Slot('push_h', 2, _bench),
  _Slot('pull_v', 2, _pullV),
  _Slot('hinge', 2, ['romanian_deadlift', 'glute_bridge']),
  _Slot('push_v', 3),
  _Slot('pull_h', 3),
  _Slot('core', 3),
  _Slot('lunge', 3),
]);

/// Сборщик тренировок: по формату, уровню и инвентарю — дни по 6–8 упражнений,
/// подходы разложены так, чтобы за неделю каждая мышца получила свою норму.
class SessionBuilder {
  const SessionBuilder._();

  /// Шаблон недели: 3 тренировки — всё тело, 4 — верх/низ, 5+ — плюс день
  /// отстающей части; сплит — три дня по кругу.
  static List<_DayTemplate> _templates(int sessionsPerWeek, bool split) =>
      switch (sessionsPerWeek) {
        _ when split => const [_splitBack, _splitChest, _splitLegs],
        <= 3 => const [_fullBodyA, _fullBodyB],
        4 => const [_upper, _lower],
        _ => const [_upper, _lower, _focus],
      };

  /// Дни программы. [stepOf] — ступень человека в движении (лесенка),
  /// [start] — фаза «Старт»: меньше подходов, больше повторов, больше запаса.
  static List<ProgramDay> days({
    required TrainingLevel level,
    required int sessionsPerWeek,
    required Equipment equipment,
    required int Function(String pattern) stepOf,
    bool split = false,
    bool start = false,
    BodyPart? lagging,
  }) {
    final templates = _templates(sessionsPerWeek, split);
    // Новичок в зале в фазе «Старт»: основа — свой вес (присед, отжимания, выпады,
    // пресс, гравитрон), с инвентарём — 2–3 упражнения с небольшим весом (13.3).
    final bodyweightFirst =
        start && level == TrainingLevel.novice && equipment == Equipment.gym;
    final picked = [
      for (final t in templates)
        _pick(
          t,
          level,
          equipment,
          stepOf,
          t == _focus ? lagging : null,
          bodyweightFirst: bodyweightFirst,
        ),
    ];
    final sets = _distributeSets(
      picked,
      level: level,
      sessionsPerWeek: sessionsPerWeek,
      start: start,
      lagging: lagging,
    );
    return [
      for (final (d, t) in templates.indexed)
        ProgramDay(t.id, t.title, [
          for (final (i, choice) in picked[d].indexed)
            _planned(choice, sets[d][i], level, start),
        ]),
    ];
  }

  /// Упражнения дня: по приоритету, не больше нормы уровня, без повторов.
  static List<({Exercise exercise, bool compound})> _pick(
    _DayTemplate t,
    TrainingLevel level,
    Equipment equipment,
    int Function(String pattern) stepOf,
    BodyPart? lagging, {
    bool bodyweightFirst = false,
  }) {
    var slots = [...t.slots];
    if (lagging != null && lagging != BodyPart.cardio) {
      // В день отстающей части её движения — первыми и обязательными.
      final forPart = _partSlots[lagging] ?? const <_Slot>[];
      slots = [...forPart, ...slots];
    }
    final used = <String>{};
    final chosen =
        <(int, int, Exercise, bool)>[]; // приоритет, порядок, упражнение
    for (final (order, slot) in slots.indexed) {
      final e = _exerciseFor(
        slot,
        equipment,
        stepOf,
        used,
        bodyweightFirst: bodyweightFirst,
      );
      if (e == null) continue;
      used.add(e.id);
      chosen.add((slot.priority, order, e, slot.compound));
    }
    final byPriority = [...chosen]
      ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    final kept = byPriority.take(level.exercises).toList()
      ..sort((a, b) => a.$2 - b.$2);
    return [for (final c in kept) (exercise: c.$3, compound: c.$4)];
  }

  /// Движения, где новичку в зале на старте сначала даём свой вес (TRAINING_SYSTEM.md 13.3).
  static const _bodyweightBasics = {
    'squat',
    'push_h',
    'lunge',
    'core',
    'pull_v',
  };

  /// Движения под отстающую часть тела (день отстающей части).
  static const _partSlots = <BodyPart, List<_Slot>>{
    BodyPart.chest: [
      _Slot('push_h', 1),
      _Slot('push_h', 1, ['db_bench_press', 'push_up', 'machine_chest_press']),
    ],
    BodyPart.back: [_Slot('pull_v', 1), _Slot('pull_h', 1)],
    BodyPart.arms: [_Slot('biceps', 1), _Slot('triceps', 1), _Slot('delts', 1)],
    BodyPart.legs: [_Slot('squat', 1), _Slot('lunge', 1)],
    BodyPart.core: [
      _Slot('core', 1),
      _Slot('core', 1, ['side_plank', 'russian_twist']),
    ],
  };

  /// Упражнение слота: из предпочтений — первое доступное; иначе вариант
  /// движения ближе всего к ступени человека (при равенстве — попроще).
  static Exercise? _exerciseFor(
    _Slot slot,
    Equipment equipment,
    int Function(String pattern) stepOf,
    Set<String> used, {
    bool bodyweightFirst = false,
  }) {
    bool ok(Exercise e) => isAvailable(e.id, equipment) && !used.contains(e.id);
    final preferBodyweight =
        bodyweightFirst && _bodyweightBasics.contains(slot.pattern);
    final step = stepOf(slot.pattern);
    if (slot.prefer.isNotEmpty) {
      final options = [
        for (final id in slot.prefer)
          if (ExerciseCatalog.tryById(id) case final e? when ok(e))
            // Новичку в зале — только варианты со своим весом; нет таких в
            // предпочтениях — ищем по всей базе ниже.
            if (!preferBodyweight || !e.usesWeight) e,
      ];
      // Из предпочтений — первое не сложнее ступени человека, иначе самое простое.
      final fit = options.where((e) => e.difficulty <= step).firstOrNull;
      if (fit != null) return fit;
      // Новичку в зале не даём сложное из предпочтений — ищем проще по всей базе.
      if (options.isNotEmpty && !preferBodyweight) {
        return options.reduce((a, b) => a.difficulty <= b.difficulty ? a : b);
      }
    }
    final options =
        ExerciseCatalog.all
            .where((e) => e.pattern == slot.pattern && ok(e))
            .toList()
          ..sort((a, b) {
            // Ближе к ступени, в зале — с весом (его видно, как растёт), потом попроще.
            int rank(Exercise e) =>
                (e.difficulty - step).abs() * 10 +
                (preferBodyweight
                    ? (e.usesWeight ? 5 : 0)
                    : (equipment == Equipment.gym && !e.usesWeight ? 5 : 0)) +
                e.difficulty;
            return rank(a) - rank(b);
          });
    return options.firstOrNull;
  }

  /// Подходы: база (2–3), потом по одному добавляются туда, где мышце за неделю
  /// не хватает до нормы, — упражнению, которое нагружает её сильнее всего.
  static List<List<int>> _distributeSets(
    List<List<({Exercise exercise, bool compound})>> days, {
    required TrainingLevel level,
    required int sessionsPerWeek,
    required bool start,
    BodyPart? lagging,
  }) {
    // Отстающей части — на четверть больше подходов, чтобы догоняла.
    double target(Muscle m) =>
        weeklyTarget(m, level) * (m.part == lagging ? 1.25 : 1);
    final maxSets = start ? 2 : level.maxSets;
    // База: новичку по 2 подхода, остальным по 3; дальше добирается до нормы.
    final base = start || level == TrainingLevel.novice ? 2 : 3;
    final sets = [for (final d in days) List.filled(d.length, base)];
    if (days.isEmpty || start) return sets;
    // Сколько раз за неделю повторяется каждый день цикла.
    final repeats = List.filled(days.length, 0);
    for (var i = 0; i < sessionsPerWeek; i++) {
      repeats[i % days.length]++;
    }
    double weekly(Muscle m) {
      var total = 0.0;
      for (final (d, day) in days.indexed) {
        for (final (i, c) in day.indexed) {
          total += sets[d][i] * setCredit(c.exercise.id, m) * repeats[d];
        }
      }
      return total;
    }

    int dayTotal(int d) => sets[d].fold(0, (a, b) => a + b);

    // Мышцы, которые в этой программе нечем догрузить, — пропускаем.
    final exhausted = <Muscle>{};
    for (var guard = 0; guard < 300; guard++) {
      // Самая недогруженная мышца (по доле от нормы).
      Muscle? worst;
      var worstRatio = 1.0;
      for (final m in Muscle.values) {
        if (exhausted.contains(m)) continue;
        final ratio = weekly(m) / target(m);
        if (ratio < worstRatio) {
          worst = m;
          worstRatio = ratio;
        }
      }
      if (worst == null) break;
      // Куда добавить подход: самое нагружающее её упражнение, где ещё есть место.
      (int, int)? best;
      var bestCredit = 0.0;
      for (final (d, day) in days.indexed) {
        if (repeats[d] == 0 || dayTotal(d) >= level.daySets) continue;
        for (final (i, c) in day.indexed) {
          final credit = setCredit(c.exercise.id, worst) * repeats[d];
          if (sets[d][i] < maxSets && credit > bestCredit) {
            best = (d, i);
            bestCredit = credit;
          }
        }
      }
      if (best == null || bestCredit < 0.25) {
        exhausted.add(worst);
        continue;
      }
      sets[best.$1][best.$2]++;
    }
    return sets;
  }

  static PlannedExercise _planned(
    ({Exercise exercise, bool compound}) c,
    int sets,
    TrainingLevel level,
    bool start,
  ) {
    final e = c.exercise;
    if (e.unit == ExerciseUnit.seconds) {
      return PlannedExercise(
        e.id,
        sets: sets,
        repsMin: start ? 20 : 30,
        repsMax: start ? 30 : 45,
        repsInReserve: start ? 3 : 2,
      );
    }
    if (start) {
      return PlannedExercise(
        e.id,
        sets: sets,
        repsMin: 10,
        repsMax: 12,
        repsInReserve: 3,
      );
    }
    // Базовые — тяжелее (опытным 6–10), изоляция — 10–15.
    final heavy = c.compound && level == TrainingLevel.advanced;
    return PlannedExercise(
      e.id,
      sets: sets,
      repsMin: c.compound ? (heavy ? 6 : 8) : 10,
      repsMax: c.compound ? (heavy ? 10 : 12) : 15,
      repsInReserve: level == TrainingLevel.advanced ? 1 : 2,
    );
  }

  /// Подходов в неделю на каждую мышцу по плану — для экрана анализа.
  static Map<Muscle, double> weeklyPlan(
    List<ProgramDay> days,
    int sessionsPerWeek,
  ) {
    final out = <Muscle, double>{};
    if (days.isEmpty) return out;
    for (var s = 0; s < sessionsPerWeek; s++) {
      for (final p in days[s % days.length].exercises) {
        for (final m in Muscle.values) {
          final c = setCredit(p.exerciseId, m);
          if (c > 0) out[m] = (out[m] ?? 0) + c * p.sets;
        }
      }
    }
    return out;
  }
}

/// Уровень по анкете: опыт и самопроверка (отжимания, подтягивания). Тесты
/// поднимают уровень не больше чем на ступень выше заявленного опыта.
TrainingLevel declaredLevel({
  required int experience,
  int? pushUps,
  int? pullUps,
}) {
  final byAnswer = switch (experience) {
    >= 3 => TrainingLevel.advanced,
    2 => TrainingLevel.intermediate,
    _ => TrainingLevel.novice,
  };
  final push = pushUps ?? 0;
  final pull = pullUps ?? 0;
  final byTest = pull >= 12 && push >= 40
      ? TrainingLevel.advanced
      : pull >= 5 || push >= 25
      ? TrainingLevel.intermediate
      : TrainingLevel.novice;
  final capped = TrainingLevel.values[(byAnswer.index + 1).clamp(0, 2)];
  final test = byTest.index > capped.index ? capped : byTest;
  return test.index > byAnswer.index ? test : byAnswer;
}

/// Основные движения: по ним видно, что человек вырос.
const mainPatterns = [
  'squat',
  'hinge',
  'push_h',
  'pull_v',
  'pull_h',
  'push_v',
  'lunge',
];

/// Уровень по делу: заметная прогрессия поднимает уровень выше анкетного.
/// Средний — 24 тренировки и три основных движения на 2-й ступени;
/// опытный — 60 тренировок и три движения на 3-й.
TrainingLevel provenLevel({
  required int completedWorkouts,
  required int Function(String pattern) stepOf,
}) {
  int atLeast(int step) => mainPatterns.where((p) => stepOf(p) >= step).length;
  if (completedWorkouts >= 60 && atLeast(3) >= 3) return TrainingLevel.advanced;
  if (completedWorkouts >= 24 && atLeast(2) >= 3) {
    return TrainingLevel.intermediate;
  }
  return TrainingLevel.novice;
}
