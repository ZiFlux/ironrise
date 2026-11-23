import 'body_part.dart';
import 'exercise_catalog.dart';
import 'muscles.dart';
import 'program.dart';
import 'training_format.dart';
import 'goal_path.dart';
import '../state/hero.dart' show Goal;

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
const _fly = ['pec_deck', 'cable_fly', 'db_fly'];

/// Движения низа: по ним видно, что день тренирует ноги.
const _lowerPatterns = {'squat', 'hinge', 'lunge'};

/// Упражнения с меткой `f` (shared/exercises.json) — чаще выбирают девушки.
/// По полу аватара: девушкам — небольшой приоритет и ягодичная изоляция в дни ног,
/// остальным — только если другого варианта нет.
bool _marked(Exercise e) => e.marker == 'f';

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
  _Slot('chest_fly', 3, _fly),
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

/// Сплит (п. 41) по схеме тренеров «тяни / толкай / ноги»: каждая мышца — в свой
/// день вместе с теми, что ей помогают, и не работает два дня подряд.
/// Спина и бицепс (бицепс помогает в тягах), задние дельты и трапеции — тоже тянут.
const _splitBack = _DayTemplate('S1', 'Спина и бицепс', [
  _Slot('pull_v', 1, _pullV),
  _Slot('pull_h', 1, _pullH),
  _Slot('biceps', 1),
  _Slot('rear_delts', 2, ['face_pull', 'reverse_pec_deck', 'rear_delt_fly']),
  _Slot('traps', 2),
  _Slot('pull_h', 2, ['seated_cable_row', 'chest_supported_row', 'db_row']),
  _Slot('biceps', 2, ['hammer_curl', 'concentration_curl', 'cable_curl']),
  _Slot('core', 3, ['hanging_knee_raise', 'reverse_crunch', 'crunches']),
  _Slot('lats_iso', 3),
]);

/// Грудь, трицепс (помогает в жимах) и предплечья; косые мышцы живота.
const _splitChest = _DayTemplate('S2', 'Грудь, трицепс, предплечья', [
  _Slot('push_h', 1, _bench),
  _Slot('push_h', 1, [
    'incline_db_press',
    'incline_bench_press',
    'db_bench_press',
    'decline_push_up',
    'push_up',
  ]),
  _Slot('triceps', 1),
  _Slot('chest_fly', 2, _fly),
  _Slot('triceps', 2, [
    'french_press',
    'overhead_db_extension',
    'cable_overhead_extension',
    'bench_dips',
  ]),
  _Slot('forearms', 2, ['wrist_curl', 'reverse_curl', 'reverse_wrist_curl']),
  _Slot('core', 3, ['oblique_crunch', 'side_plank', 'russian_twist']),
  _Slot('push_h', 3, ['dips', 'wide_push_up', 'push_up']),
]);

/// Ноги и плечи: все три пучка дельт (жим — передние, отведения — средние),
/// икры. Плечи не работают накануне дня груди: там жимы снова грузят передние.
const _splitLegs = _DayTemplate('S3', 'Ноги и плечи', [
  _Slot('squat', 1, _squat),
  _Slot('push_v', 1, _press),
  _Slot('hinge', 1, ['romanian_deadlift', 'deadlift', 'glute_bridge']),
  _Slot('delts', 1),
  _Slot('lunge', 2),
  _Slot('calves', 2),
  _Slot('hinge', 2, ['leg_curl', 'lying_leg_curl', 'towel_leg_curl']),
  _Slot('front_delts', 3),
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

/// Раскладка дней по кругу для «подбери сам».
enum Rotation { fullBody, upperLower, split }

/// Сборщик тренировок: по формату, уровню и инвентарю — дни по 6–8 упражнений,
/// подходы разложены так, чтобы за неделю каждая мышца получила свою норму.
class SessionBuilder {
  const SessionBuilder._();

  /// Раскладка по кругу (TRAINING_SYSTEM.md 14): стиль игрока на любое число дней.
  /// [adjacent] — среди дней есть соседние: «всё тело» тогда нагрузило бы одни мышцы
  /// два дня подряд, и программа берёт верх/низ. [weekdays] — дни графика
  /// (0 — понедельник): с ними «подбери сам» выбирает раскладку по оценке недели.
  static List<_DayTemplate> _templates(
    TrainingFormat format,
    int sessionsPerWeek,
    TrainingLevel level, {
    required bool start,
    required bool adjacent,
    List<int>? weekdays,
  }) {
    const fullBody = [_fullBodyA, _fullBodyB];
    const upperLower = [_upper, _lower];
    const split = [_splitBack, _splitChest, _splitLegs];
    // «Старт»: всё тело, а при соседних днях — верх/низ.
    if (start) return adjacent ? upperLower : fullBody;
    return switch (format) {
      TrainingFormat.fullBody ||
      TrainingFormat.minimum => adjacent ? upperLower : fullBody,
      TrainingFormat.upperLower => upperLower,
      TrainingFormat.split => split,
      TrainingFormat.custom when weekdays != null && weekdays.length >= 2 =>
        switch (bestRotation(weekdays, level)) {
          Rotation.fullBody => fullBody,
          Rotation.upperLower => upperLower,
          Rotation.split => split,
        },
      TrainingFormat.custom => switch (sessionsPerWeek) {
        <= 2 => adjacent ? upperLower : fullBody,
        3 when level == TrainingLevel.novice && !adjacent => fullBody,
        3 => split,
        4 => upperLower,
        _ => split,
      },
    };
  }

  /// Группы мышц, по которым считается частота: какие движения их грузят.
  static const _groupOf = <String, String>{
    'push_h': 'chest',
    'chest_fly': 'chest',
    'pull_v': 'back',
    'pull_h': 'back',
    'lats_iso': 'back',
    'squat': 'legs',
    'hinge': 'legs',
    'lunge': 'legs',
    'quads': 'legs',
    'push_v': 'shoulders',
    'delts': 'shoulders',
    'front_delts': 'shoulders',
    'rear_delts': 'rear',
    'biceps': 'biceps',
    'triceps': 'triceps',
  };

  /// Вес группы в оценке: мелкие (бицепс, трицепс, задние дельты) и так работают
  /// в базовых движениях — им половина.
  static const _groupWeight = <String, double>{
    'biceps': 0.5,
    'triceps': 0.5,
    'rear': 0.5,
  };

  static Set<String> _groupsOf(_DayTemplate t) => {
    for (final slot in t.slots)
      if (slot.priority <= 2) ?_groupOf[slot.pattern],
  };

  /// Оценка раскладки на конкретных днях недели (docs/TRAINING_SYSTEM.md 14.1):
  /// - каждой группе мышц — 2 тренировки в неделю: это лучше одной при той же
  ///   работе (Schoenfeld 2016), больше двух — уже без заметной прибавки;
  /// - одна группа — не чаще раза в 48 часов (не два дня подряд);
  /// - уровень (ACSM 2009): новичку — всё тело, опытному с 5 днями — сплит.
  /// Цикл дней идёт по кругу через недели, поэтому считаем на 6 недель.
  static double rotationScore(
    Rotation rotation,
    List<int> weekdays,
    TrainingLevel level,
  ) {
    final days = {...weekdays}.toList()..sort();
    if (days.isEmpty) return double.negativeInfinity;
    final templates = switch (rotation) {
      Rotation.fullBody => const [_fullBodyA, _fullBodyB],
      Rotation.upperLower => const [_upper, _lower],
      Rotation.split => const [_splitBack, _splitChest, _splitLegs],
    };
    const weeks = 6;
    final hits = <String, int>{};
    var backToBack = 0;
    Set<String>? previous;
    var previousDay = -10;
    var i = 0;
    for (var w = 0; w < weeks; w++) {
      for (final d in days) {
        final groups = _groupsOf(templates[i % templates.length]);
        i++;
        for (final g in groups) {
          hits[g] = (hits[g] ?? 0) + 1;
        }
        final day = w * 7 + d;
        if (previous != null && day - previousDay == 1) {
          backToBack += groups.intersection(previous).length;
        }
        previous = groups;
        previousDay = day;
      }
    }
    var score = 0.0;
    for (final g in _groupOf.values.toSet()) {
      final perWeek = (hits[g] ?? 0) / weeks;
      score += 10 * (_groupWeight[g] ?? 1) * (perWeek < 2 ? perWeek : 2);
    }
    score -= 15 * backToBack / weeks;
    score += switch ((rotation, level)) {
      (Rotation.split, TrainingLevel.novice) => -10,
      (Rotation.upperLower, TrainingLevel.novice) => -2,
      (Rotation.fullBody, TrainingLevel.advanced) when days.length >= 4 => -6,
      (Rotation.split, TrainingLevel.advanced) when days.length >= 5 => 10,
      _ => 0,
    };
    // Всё тело чаще трёх раз в неделю — каждая тренировка снова те же мышцы.
    if (rotation == Rotation.fullBody && days.length > 3) score -= 8;
    return score;
  }

  /// Лучшая раскладка для дней графика — по [rotationScore]; при равенстве — проще.
  static Rotation bestRotation(List<int> weekdays, TrainingLevel level) {
    var best = Rotation.fullBody;
    var bestScore = double.negativeInfinity;
    for (final r in Rotation.values) {
      final score = rotationScore(r, weekdays, level);
      if (score > bestScore + 0.01) {
        best = r;
        bestScore = score;
      }
    }
    return best;
  }

  /// Порядок упражнений дня: подряд — разные мышцы (широчайшие → бицепс →
  /// широчайшие…): пока одна отдыхает, работает другая. Из оставшихся берётся
  /// первое по плану, не похожее на предыдущее; пресс, икры и предплечья — в
  /// конце (уставшие хват и пресс мешали бы базовым движениям).
  static List<({Exercise exercise, bool compound})> alternate(
    List<({Exercise exercise, bool compound})> list,
  ) {
    const finishers = {'core', 'calves', 'forearms', 'conditioning'};
    final main = [
      for (final c in list)
        if (!finishers.contains(c.exercise.pattern)) c,
    ];
    final tail = [
      for (final c in list)
        if (finishers.contains(c.exercise.pattern)) c,
    ];
    final out = <({Exercise exercise, bool compound})>[];
    while (main.isNotEmpty) {
      final prev = out.lastOrNull?.exercise;
      var index = 0;
      if (prev != null) {
        final fit = main.indexWhere(
          (c) =>
              primaryMuscleOf(c.exercise.id) != primaryMuscleOf(prev.id) &&
              muscleOverlapOf(c.exercise.id, prev.id) < 0.4,
        );
        if (fit >= 0) index = fit;
      }
      out.add(main.removeAt(index));
    }
    return [...out, ...tail];
  }

  /// Дни программы. [stepOf] — ступень человека в движении (лесенка),
  /// [start] — фаза «Старт»: меньше подходов, больше повторов, больше запаса.
  static List<ProgramDay> days({
    required TrainingLevel level,
    required int sessionsPerWeek,
    required Equipment equipment,
    required int Function(String pattern) stepOf,
    TrainingFormat format = TrainingFormat.custom,
    bool adjacent = false,
    List<int>? weekdays,
    bool start = false,
    BodyPart? lagging,
    Goal? goal,
    bool female = false,
  }) {
    // Путь цели (п. 117): «Старт» одинаков для всех — без него.
    final path = start || goal == null ? null : GoalPath.of(goal, level);
    final maxExercises = (level.exercises + (path?.exerciseDelta ?? 0)).clamp(
      4,
      8,
    );
    final templates = _templates(
      format,
      sessionsPerWeek,
      level,
      start: start,
      adjacent: adjacent,
      weekdays: weekdays,
    );
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
          // Отстающая часть — в дни, которые и так её тренируют: так она получает
          // больше работы без перекрытия соседних дней (TRAINING_SYSTEM.md 14).
          t == _focus || _trains(t, lagging) ? lagging : null,
          bodyweightFirst: bodyweightFirst,
          maxExercises: maxExercises,
          female: female,
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
            _planned(choice, sets[d][i], level, start, path: path),
          if (path?.finisher ?? false) _finisher(d, level),
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
    int? maxExercises,
    bool female = false,
  }) {
    var slots = [...t.slots];
    if (female) slots = _femaleSlots(slots);
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
        female: female,
      );
      if (e == null) continue;
      used.add(e.id);
      chosen.add((slot.priority, order, e, slot.compound));
    }
    final byPriority = [...chosen]
      ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    final kept = byPriority.take(maxExercises ?? level.exercises).toList()
      ..sort((a, b) => a.$2 - b.$2);
    return alternate([for (final c in kept) (exercise: c.$3, compound: c.$4)]);
  }

  /// Слоты дня для девушки: в ягодичных шарнирах первым — мост со штангой,
  /// в дни ног после первого движения низа — ягодичная изоляция (приоритет 2,
  /// раньше прочих необязательных), в конце — сведение ног.
  static List<_Slot> _femaleSlots(List<_Slot> slots) {
    final out = [
      for (final s in slots)
        s.pattern == 'hinge' && s.prefer.contains('glute_bridge')
            ? _Slot(s.pattern, s.priority, ['hip_thrust', ...s.prefer])
            : s,
    ];
    final firstLower = out.indexWhere(
      (s) => _lowerPatterns.contains(s.pattern),
    );
    if (firstLower < 0) return out;
    out.insert(
      firstLower + 1,
      const _Slot('glutes_iso', 2, [
        'hip_abduction',
        'cable_kickback',
        'donkey_kick',
      ]),
    );
    out.add(const _Slot('adductors', 3));
    return out;
  }

  /// День тренирует эту часть тела: в нём есть её движения.
  static bool _trains(_DayTemplate t, BodyPart? part) {
    final patterns = {
      for (final slot in _partSlots[part] ?? const <_Slot>[]) slot.pattern,
    };
    return patterns.isNotEmpty &&
        t.slots.any((s) => patterns.contains(s.pattern));
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
    bool female = false,
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
                e.difficulty +
                (_marked(e) ? (female ? -4 : 15) : 0);
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

  /// Финишер «на дыхалку» в конце дня (похудеть, выносливость): 2 подхода, по кругу
  /// между днями. Новичку — без прыжков в упор: «звёздочка» и скалолаз.
  static PlannedExercise _finisher(int day, TrainingLevel level) {
    const easy = ['jumping_jacks', 'mountain_climber'];
    const hard = ['burpee', 'jump_squat', 'mountain_climber'];
    final pool = level == TrainingLevel.novice ? easy : hard;
    final e = ExerciseCatalog.byId(pool[day % pool.length]);
    final seconds = e.unit == ExerciseUnit.seconds;
    return PlannedExercise(
      e.id,
      sets: 2,
      repsMin: seconds ? 30 : 10,
      repsMax: seconds ? 45 : 15,
      repsInReserve: 2,
    );
  }

  static PlannedExercise _planned(
    ({Exercise exercise, bool compound}) c,
    int sets,
    TrainingLevel level,
    bool start, {
    GoalPath? path,
  }) {
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
    // Путь цели: свои повторы и запас (п. 117).
    if (path != null) {
      final (lo, hi) = c.compound ? path.compoundReps : path.isolationReps;
      final reserve =
          (level == TrainingLevel.advanced ? 1 : 2) + path.reserveDelta;
      return PlannedExercise(
        e.id,
        sets: sets,
        repsMin: lo,
        repsMax: hi,
        repsInReserve: reserve.clamp(0, 3),
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
