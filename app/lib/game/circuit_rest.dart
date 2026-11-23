/// Отдых между кардио-упражнениями (бёрпи, скалолаз, «звёздочка», прыжки):
/// короче силового, чтобы пульс держался в рабочей зоне (≈ 70–85 % от
/// максимума) — человеку не плохо, но и не успевает остыть.
///
/// Основа (docs/TRAINING_SYSTEM.md 18): в круговых тренировках новичкам советуют
/// работать вдвое дольше, чем отдыхать, и отдыхать 15–30 с; прогресс — убирать
/// отдых. В интервалах 30 с работы на 30 с отдыха пульс держится около 82 %
/// от максимума. Мы начинаем осторожнее и сокращаем отдых по ответам после
/// тренировки, но не меньше 30 с.
library;

import 'exercise_catalog.dart';
import 'session_builder.dart' show TrainingLevel;

/// Кардио-упражнение: отдых после него — короткий.
bool isConditioning(Exercise e) => e.pattern == 'conditioning';

/// Ответ после тренировки: каким был темп кардио.
enum CircuitPace {
  tooHard('Тяжело, задыхался'),
  right('В самый раз'),
  easy('Мог бы бодрее');

  const CircuitPace(this.label);
  final String label;
}

/// Отдых между кардио-подходами и сколько раз подряд было «в самый раз».
class CircuitRest {
  const CircuitRest({required this.seconds, this.rightInARow = 0});

  final int seconds;
  final int rightInARow;

  static const minSeconds = 30;
  static const maxSeconds = 90;

  /// «В самый раз» столько раз подряд — отдых короче на шаг.
  static const rightToShorten = 2;

  /// Старт по уровню: новичку — минута, дальше короче.
  static CircuitRest start(TrainingLevel level) => CircuitRest(
    seconds: switch (level) {
      TrainingLevel.novice => 60,
      TrainingLevel.intermediate => 45,
      TrainingLevel.advanced => 30,
    },
  );

  /// Следующий отдых по ответу: тяжело — +15 с; легко — −10 с; в самый раз
  /// два раза подряд — −5 с (постепенно, чтобы не перегнуть).
  CircuitRest after(CircuitPace pace) {
    int clamp(int s) => s.clamp(minSeconds, maxSeconds);
    return switch (pace) {
      CircuitPace.tooHard => CircuitRest(seconds: clamp(seconds + 15)),
      CircuitPace.easy => CircuitRest(seconds: clamp(seconds - 10)),
      CircuitPace.right when rightInARow + 1 >= rightToShorten => CircuitRest(
        seconds: clamp(seconds - 5),
      ),
      CircuitPace.right => CircuitRest(
        seconds: seconds,
        rightInARow: rightInARow + 1,
      ),
    };
  }

  Map<String, dynamic> toJson() => {'s': seconds, 'r': rightInARow};

  factory CircuitRest.fromJson(Map<String, dynamic> j) => CircuitRest(
    seconds: ((j['s'] as num?)?.toInt() ?? 60).clamp(minSeconds, maxSeconds),
    rightInARow: (j['r'] as num?)?.toInt() ?? 0,
  );
}
