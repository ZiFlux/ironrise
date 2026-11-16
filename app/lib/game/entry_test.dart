import '../state/hero.dart' show Sex;
import 'session_builder.dart';

/// Входная тренировка (п. 116, TRAINING_SYSTEM.md 13.3–13.4): короткая домашняя
/// проверка без инвентаря. Не тест на максимум — до первого повтора с плохой техникой.
enum EntryTestItem {
  pushUps(
    'Отжимания',
    'До первого повтора с плохой техникой: тело прямое, грудь почти касается пола. '
        'Тяжело — отжимайся с колен и отметь это.',
    timed: false,
  ),
  squats60(
    'Приседания за 60 секунд',
    'Сколько успеешь за минуту: бёдра до параллели, пятки на полу, спина прямая.',
    timed: true,
  ),
  crunches60(
    'Скручивания за 60 секунд',
    'Лёжа, колени согнуты: отрывай лопатки, поясница прижата, шею руками не тяни.',
    timed: true,
  ),
  burpees60(
    'Бёрпи за 60 секунд',
    'Присед → упор лёжа → назад → прыжок. Тяжело — вместо прыжка подъём на носки. '
        'Голова кружится или давит в груди — сразу стоп.',
    timed: true,
  ),
  plank(
    'Планка',
    'На предплечьях, тело прямое. Держи, пока таз не начнёт провисать, но не дольше 2 минут.',
    timed: false,
  ),
  pullUps(
    'Подтягивания',
    'Только если есть турник. Подбородок над перекладиной, вниз — до прямых рук, без рывков.',
    timed: false,
  );

  const EntryTestItem(this.title, this.how, {required this.timed});

  final String title;
  final String how;

  /// Упражнение на время: 60 секунд, считаем повторы.
  final bool timed;

  /// Единица результата.
  String get unit => this == plank ? 'с' : 'раз';

  /// Отдых после упражнения: после бёрпи пульс высокий — дольше.
  Duration get restAfter => this == burpees60
      ? const Duration(minutes: 2)
      : const Duration(seconds: 90);
}

/// Потолок планки — дольше не держим (TRAINING_SYSTEM.md 13.3).
const plankMaxSeconds = 120;

/// Результаты: повторы или секунды; подтягивания — null, если турника нет.
class EntryTestResult {
  const EntryTestResult({
    required this.at,
    required this.pushUps,
    required this.kneePushUps,
    required this.squats60,
    required this.crunches60,
    required this.burpees60,
    required this.plankSec,
    this.pullUps,
  });

  final DateTime at;
  final int pushUps;
  final bool kneePushUps;
  final int squats60;
  final int crunches60;
  final int burpees60;
  final int plankSec;
  final int? pullUps;

  int? valueOf(EntryTestItem item) => switch (item) {
    EntryTestItem.pushUps => pushUps,
    EntryTestItem.squats60 => squats60,
    EntryTestItem.crunches60 => crunches60,
    EntryTestItem.burpees60 => burpees60,
    EntryTestItem.plank => plankSec,
    EntryTestItem.pullUps => pullUps,
  };

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'pushUps': pushUps,
    'kneePushUps': kneePushUps,
    'squats60': squats60,
    'crunches60': crunches60,
    'burpees60': burpees60,
    'plankSec': plankSec,
    'pullUps': pullUps,
  };

  /// Для сервера: те же поля без даты.
  Map<String, dynamic> resultsJson() => toJson()..remove('at');

  factory EntryTestResult.fromJson(Map<String, dynamic> j) => EntryTestResult(
    at: DateTime.parse(j['at'] as String),
    pushUps: j['pushUps'] as int,
    kneePushUps: j['kneePushUps'] as bool? ?? false,
    squats60: j['squats60'] as int,
    crunches60: j['crunches60'] as int,
    burpees60: j['burpees60'] as int,
    plankSec: j['plankSec'] as int,
    pullUps: j['pullUps'] as int?,
  );
}

/// Пороги «средний» и «опытный» (TRAINING_SYSTEM.md 13.4) — ниже первого порога «новичок».
/// Скручивания и бёрпи — пороги пользователя (16.11): 55+ и 30+ — отлично,
/// меньше 30 и 15–18 — маловато. Числа — ориентир, на проверку специалисту.
(int, int) entryThresholds(EntryTestItem item, Sex? sex) {
  final female = sex == Sex.female;
  return switch (item) {
    EntryTestItem.pushUps => female ? (5, 20) : (10, 30),
    EntryTestItem.squats60 => (25, 40),
    EntryTestItem.crunches60 => (30, 55),
    EntryTestItem.burpees60 => (19, 30),
    EntryTestItem.plank => (45, 90),
    EntryTestItem.pullUps => female ? (1, 4) : (1, 8),
  };
}

TrainingLevel levelOfItem(EntryTestItem item, int value, Sex? sex) {
  final (mid, high) = entryThresholds(item, sex);
  return value >= high
      ? TrainingLevel.advanced
      : value >= mid
      ? TrainingLevel.intermediate
      : TrainingLevel.novice;
}

/// Уровень по большинству упражнений; при равенстве — ниже (лучше недогрузить).
/// Отжимания с колен считаются как «новичок». Подтягивания — только если были.
TrainingLevel entryLevel(EntryTestResult r, Sex? sex) {
  final votes = <TrainingLevel>[
    r.kneePushUps
        ? TrainingLevel.novice
        : levelOfItem(EntryTestItem.pushUps, r.pushUps, sex),
    levelOfItem(EntryTestItem.squats60, r.squats60, sex),
    levelOfItem(EntryTestItem.crunches60, r.crunches60, sex),
    levelOfItem(EntryTestItem.burpees60, r.burpees60, sex),
    levelOfItem(EntryTestItem.plank, r.plankSec, sex),
    if (r.pullUps != null) levelOfItem(EntryTestItem.pullUps, r.pullUps!, sex),
  ];
  final counts = {
    for (final l in TrainingLevel.values) l: votes.where((v) => v == l).length,
  };
  var best = TrainingLevel.novice;
  for (final l in TrainingLevel.values) {
    // Строго больше: при равенстве остаётся уровень ниже.
    if (counts[l]! > counts[best]!) best = l;
  }
  return best;
}

/// Повторная проверка — через 4 недели после последней.
const entryRetestAfter = Duration(days: 28);
