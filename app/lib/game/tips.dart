import 'body_part.dart';

part 'tips_more.dart';

/// «Совет дня» (PLAN.md, раздел 4.8): короткий совет и один вопрос по нему.
/// Тексты — общеизвестные безопасные принципы; перед публичным запуском
/// их должен проверить тренер или спортивный врач (TRAINING_SYSTEM.md, раздел 10).

enum TipMoment { training, rest, any }

class TipQuestion {
  const TipQuestion(this.text, this.options, this.correct);

  final String text;
  final List<String> options;
  final int correct;
}

class Tip {
  const Tip({
    required this.id,
    required this.title,
    required this.text,
    required this.question,
    this.exerciseIds = const [],
    this.part,
    this.moment = TipMoment.any,
  });

  final String id;
  final String title;
  final String text;
  final TipQuestion question;

  /// Совет про технику этих упражнений: показываем, когда они в плане.
  final List<String> exerciseIds;

  /// Совет про эту часть тела: показываем, когда она отстаёт.
  final BodyPart? part;
  final TipMoment moment;
}

/// Все советы: основные и дополнительные (tips_more.dart).
const tipLibrary = <Tip>[..._baseTips, ..._moreTips];

const _baseTips = <Tip>[
  Tip(
    id: 'squat_depth',
    title: 'Присед: колени по носкам',
    text:
        'Колени двигаются в ту же сторону, куда смотрят носки, и не заваливаются внутрь. '
        'Спина прямая, вес на всей стопе. Глубина — насколько получается без округления поясницы.',
    question: TipQuestion('Куда направлены колени в приседе?', [
      'Внутрь, друг к другу',
      'По направлению носков',
      'Строго вперёд, носки внутрь',
    ], 1),
    exerciseIds: ['barbell_squat', 'bodyweight_squat', 'lunges'],
    part: BodyPart.legs,
  ),
  Tip(
    id: 'bench_shoulders',
    title: 'Жим лёжа: лопатки сведены',
    text:
        'Перед жимом сведи и опусти лопатки, как будто прячешь их в задние карманы. '
        'Так плечевой сустав в безопасном положении, а работает грудь.',
    question: TipQuestion('Что делать с лопатками в жиме лёжа?', [
      'Свести и опустить',
      'Развести шире',
      'Не думать о них',
    ], 0),
    exerciseIds: ['bench_press', 'db_bench_press'],
    part: BodyPart.chest,
  ),
  Tip(
    id: 'pushup_line',
    title: 'Отжимания: тело — одна линия',
    text:
        'От пяток до макушки прямая линия: таз не проваливается и не задирается. '
        'Если не хватает сил на полные отжимания, делай их от скамьи — это та же техника.',
    question: TipQuestion('Если полные отжимания пока тяжело даются?', [
      'Прогнуться в пояснице',
      'Отжиматься от скамьи',
      'Пропустить упражнение',
    ], 1),
    exerciseIds: ['push_up', 'dips'],
    part: BodyPart.chest,
  ),
  Tip(
    id: 'row_elbow',
    title: 'Тяга: тянет спина, а не руки',
    text:
        'Думай о том, чтобы вести локоть назад к поясу, а не тянуть кистью. '
        'В верхней точке на секунду сведи лопатки — так включается спина.',
    question: TipQuestion('О чём думать в тяге гантели?', [
      'Тянуть кистью вверх',
      'Вести локоть назад',
      'Рывком закидывать вес',
    ], 1),
    exerciseIds: ['db_row', 'lat_pulldown', 'pull_up'],
    part: BodyPart.back,
  ),
  Tip(
    id: 'rdl_hinge',
    title: 'Румынская тяга: таз назад',
    text:
        'Движение начинается с отведения таза назад, колени чуть согнуты, спина прямая. '
        'Опускайся, пока чувствуешь натяжение задней поверхности бедра, а не до пола.',
    question: TipQuestion('С чего начинается румынская тяга?', [
      'С наклона спины вниз',
      'С отведения таза назад',
      'С приседа',
    ], 1),
    exerciseIds: ['romanian_deadlift', 'back_extension'],
    part: BodyPart.back,
  ),
  Tip(
    id: 'press_core',
    title: 'Жим сидя: не прогибайся',
    text:
        'Прижми поясницу к спинке и напряги пресс. Если для подъёма гантелей приходится '
        'прогибаться назад, вес великоват — возьми полегче.',
    question: TipQuestion('Что значит сильный прогиб в жиме сидя?', [
      'Всё правильно',
      'Вес великоват',
      'Нужно больше повторов',
    ], 1),
    exerciseIds: ['db_shoulder_press'],
    part: BodyPart.arms,
  ),
  Tip(
    id: 'plank_breath',
    title: 'Планка: дыши',
    text:
        'В планке не задерживай дыхание: дыши ровно, пресс напряжён, ягодицы тоже. '
        'Лучше 20 секунд ровной планки, чем минута с провисшей поясницей.',
    question: TipQuestion('Как дышать в планке?', [
      'Задержать дыхание',
      'Ровно и спокойно',
      'Часто и коротко',
    ], 1),
    exerciseIds: ['plank', 'crunches', 'hanging_leg_raise'],
    part: BodyPart.core,
  ),
  Tip(
    id: 'reserve_reps',
    title: 'Повторы в запасе',
    text:
        '«3 в запасе» значит: закончил подход и мог бы сделать ещё три чистых повтора. '
        'Новичкам этого достаточно для роста, а риск травмы и сильной боли на следующий день ниже.',
    question: TipQuestion('Что значит «3 повтора в запасе»?', [
      'Сделать на 3 больше плана',
      'Мог бы ещё 3, но остановился',
      'Отдыхать 3 минуты',
    ], 1),
    moment: TipMoment.training,
  ),
  Tip(
    id: 'warmup',
    title: 'Разминка за 5 минут',
    text:
        '5 минут лёгкого кардио, затем первый подход упражнения с пустым грифом или лёгким весом. '
        'Разогретые мышцы и суставы работают лучше и травмируются реже.',
    question: TipQuestion('С чего начать первое упражнение?', [
      'Сразу с рабочего веса',
      'С подхода с лёгким весом',
      'С растяжки на 20 минут',
    ], 1),
    moment: TipMoment.training,
  ),
  Tip(
    id: 'rest_between_sets',
    title: 'Отдых между подходами',
    text:
        'Для базовых упражнений отдыхай 1,5–2 минуты: этого хватает, чтобы следующий подход '
        'был таким же качественным. Таймер отдыха в приложении стоит на 90 секунд.',
    question: TipQuestion(
      'Сколько отдыхать между подходами базовых упражнений?',
      ['10–20 секунд', '1,5–2 минуты', '10 минут'],
      1,
    ),
    moment: TipMoment.training,
  ),
  Tip(
    id: 'sleep',
    title: 'Мышцы растут во сне',
    text:
        'Нагрузка — сигнал, а восстановление и рост идут в отдыхе, особенно во сне. '
        '7–9 часов сна дают больше прогресса, чем лишняя тренировка.',
    question: TipQuestion('Когда мышцы восстанавливаются и растут?', [
      'Во время подхода',
      'В отдыхе и во сне',
      'Только после протеина',
    ], 1),
    moment: TipMoment.rest,
  ),
  Tip(
    id: 'rest_day_walk',
    title: 'День отдыха — не диван',
    text:
        'Лёгкая прогулка или велосипед в день отдыха ускоряют восстановление и не мешают росту. '
        'Серия при этом не сгорает: отдых по графику в неё засчитывается.',
    question: TipQuestion('Что полезно в день отдыха?', [
      'Тяжёлая тренировка ног',
      'Лёгкая прогулка',
      'Ничего не делать неделю',
    ], 1),
    moment: TipMoment.rest,
  ),
  Tip(
    id: 'soreness',
    title: 'Крепатура — не показатель',
    text:
        'Мышцы болят на 1–2 день после новой нагрузки, и это нормально. Но сильная боль — '
        'знак, что было слишком много. Острая боль в суставе — повод остановиться и показаться врачу.',
    question: TipQuestion('Острая боль в суставе на тренировке — это…', [
      'Признак хорошей работы',
      'Повод остановиться',
      'Нужно добавить вес',
    ], 1),
    moment: TipMoment.any,
  ),
  Tip(
    id: 'protein',
    title: 'Белок в каждом приёме пищи',
    text:
        'Мясо, рыба, яйца, творог, бобовые: пусть в каждом приёме пищи будет источник белка. '
        'Это проще, чем считать граммы, и помогает мышцам восстанавливаться.',
    question: TipQuestion('Как проще всего добрать белок?', [
      'Источник белка в каждом приёме пищи',
      'Один большой стейк в неделю',
      'Только добавки',
    ], 0),
    moment: TipMoment.any,
  ),
  Tip(
    id: 'water',
    title: 'Пей воду на тренировке',
    text:
        'Небольшими глотками между подходами. Даже лёгкое обезвоживание снижает силу и '
        'делает тренировку тяжелее, чем она есть.',
    question: TipQuestion('Как пить на тренировке?', [
      'Не пить до конца',
      'Глотками между подходами',
      'Литр перед началом',
    ], 1),
    moment: TipMoment.training,
  ),
  Tip(
    id: 'cardio_zone',
    title: 'Кардио: можно говорить',
    text:
        'Пульсовая зона, которую считает приложение, — темп, в котором можно говорить, но '
        'петь уже трудно. Такое кардио тренирует сердце и не мешает силовым.',
    question: TipQuestion('Как понять, что темп кардио правильный?', [
      'Можно говорить, петь трудно',
      'Нельзя сказать ни слова',
      'Можно петь',
    ], 0),
    part: BodyPart.cardio,
  ),
  Tip(
    id: 'arms_curl',
    title: 'Сгибания: без раскачки',
    text:
        'Локти прижаты к корпусу, корпус не раскачивается. Если без рывка вес не поднимается — '
        'он тяжёлый, и работает спина, а не бицепс.',
    question: TipQuestion('Если вес поднимается только рывком корпуса?', [
      'Вес тяжёлый',
      'Так и надо',
      'Нужно быстрее',
    ], 0),
    exerciseIds: ['db_curl', 'french_press'],
    part: BodyPart.arms,
  ),
];

/// Подбор совета на день: про упражнения сегодняшнего плана, отстающую часть тела
/// или про отдых. Недавно показанные не повторяются, выбор стабилен в течение дня.
class TipPicker {
  const TipPicker._();

  static Tip pick({
    required DateTime day,
    required bool isTrainingDay,
    required List<String> planExerciseIds,
    required BodyPart? lagging,
    required List<String> recentTipIds,
    List<Tip> library = tipLibrary,
  }) {
    final fresh = library.where((t) => !recentTipIds.contains(t.id)).toList();
    final pool = fresh.isEmpty ? library : fresh;
    final relevant = pool
        .where((t) => _relevant(t, isTrainingDay, planExerciseIds, lagging))
        .toList();
    final candidates = relevant.isEmpty ? pool : relevant;
    final seed = day.year * 1000 + day.month * 40 + day.day;
    return candidates[seed % candidates.length];
  }

  /// Подборка на день: [count] разных советов — сначала по делу (план, отстающая
  /// часть, тренировка или отдых), потом остальные. Стабильна в течение дня.
  static List<Tip> pickSet({
    required DateTime day,
    required bool isTrainingDay,
    required List<String> planExerciseIds,
    required BodyPart? lagging,
    required List<String> recentTipIds,
    required int count,
    List<Tip> library = tipLibrary,
  }) {
    final fresh = library.where((t) => !recentTipIds.contains(t.id)).toList();
    final pool = fresh.length >= count ? fresh : library;
    final seed = day.year * 1000 + day.month * 40 + day.day;
    List<Tip> rotated(List<Tip> list) => list.isEmpty
        ? list
        : [
            for (var i = 0; i < list.length; i++)
              list[(seed + i) % list.length],
          ];
    final relevant = pool
        .where((t) => _relevant(t, isTrainingDay, planExerciseIds, lagging))
        .toList();
    final others = pool.where((t) => !relevant.contains(t)).toList();
    return [...rotated(relevant), ...rotated(others)].take(count).toList();
  }

  static bool _relevant(
    Tip tip,
    bool isTrainingDay,
    List<String> planExerciseIds,
    BodyPart? lagging,
  ) {
    if (lagging != null && tip.part == lagging) return true;
    if (isTrainingDay && tip.exerciseIds.any(planExerciseIds.contains))
      return true;
    return tip.moment == (isTrainingDay ? TipMoment.training : TipMoment.rest);
  }
}
