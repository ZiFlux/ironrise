/// Бой по раундам: действия, шаги и правила — как на сервере
/// (server/src/game/combat.ts, docs/COMBAT.md). Считает сервер, здесь — подписи.
library;

/// Действие шага. Порядок и имена — как в COMBAT_ACTIONS на сервере.
enum CombatAction {
  body('В корпус', 'Обычный удар'),
  legs('По ногам', 'Слабее, но подсекает отход'),
  heavy('Мощный', 'Сильный и медленный: от него легко отойти'),
  grab('Захват', 'Ломает блок и сбивает следующий шаг, но открыт для ударов'),
  block('Блок', 'Гасит удар и отвечает слабым ударом'),
  evade('Отход', 'Уходит от удара и бьёт встречным');

  const CombatAction(this.label, this.hint);
  final String label;
  final String hint;

  bool get attack => index <= CombatAction.grab.index;

  static CombatAction? byName(String? name) => values.asNameMap()[name];
}

/// Подпись действия в шаге: «Сбит», если шаг сорван захватом или событием.
String stepActionLabel(String name) =>
    CombatAction.byName(name)?.label ?? 'Сбит';

/// Что вышло у удара бойца в шаге (StepOutcome на сервере).
String outcomeLabel(String outcome) => switch (outcome) {
  'hit' => 'попал',
  'crit' => 'крит!',
  'blocked' => 'в блок',
  'evaded' => 'мимо — отход',
  'broken' => 'сломал блок',
  'grabbed' => 'захватил',
  'countered' => 'сорвали',
  'riposte' => 'ответный',
  _ => '',
};

class CombatStep {
  const CombatStep({
    required this.round,
    required this.step,
    required this.a,
    required this.d,
    required this.toD,
    required this.toA,
    required this.outA,
    required this.outD,
    required this.hpA,
    required this.hpD,
    this.eventId,
    this.eventOwnerIsAttacker = false,
  });

  final int round;
  final int step;

  /// Имена действий (CombatAction.name или none).
  final String a;
  final String d;
  final int toD;
  final int toA;
  final String outA;
  final String outD;
  final int hpA;
  final int hpD;
  final String? eventId;
  final bool eventOwnerIsAttacker;

  factory CombatStep.fromJson(Map<String, dynamic> j) => CombatStep(
    round: (j['round'] as num).toInt(),
    step: (j['step'] as num).toInt(),
    a: j['a'] as String,
    d: j['d'] as String,
    toD: (j['toD'] as num).toInt(),
    toA: (j['toA'] as num).toInt(),
    outA: j['outA'] as String,
    outD: j['outD'] as String,
    hpA: (j['hpA'] as num).toInt(),
    hpD: (j['hpD'] as num).toInt(),
    eventId: (j['event'] as Map?)?['id'] as String?,
    eventOwnerIsAttacker: (j['event'] as Map?)?['owner'] == 'attacker',
  );
}

class CombatRules {
  const CombatRules({
    this.rounds = 6,
    this.steps = 5,
    this.maxHeavy = 2,
    this.maxSameInRow = 3,
  });

  final int rounds;
  final int steps;
  final int maxHeavy;
  final int maxSameInRow;

  factory CombatRules.fromJson(Map<String, dynamic> j) => CombatRules(
    rounds: (j['rounds'] as num?)?.toInt() ?? 6,
    steps: (j['steps'] as num?)?.toInt() ?? 5,
    maxHeavy: (j['maxHeavy'] as num?)?.toInt() ?? 2,
    maxSameInRow: (j['maxSameInRow'] as num?)?.toInt() ?? 3,
  );

  /// Можно ли добавить [a] в конец начатой цепочки.
  bool allows(List<CombatAction> chain, CombatAction a) {
    if (chain.length >= steps) return false;
    if (a == CombatAction.heavy &&
        chain.where((x) => x == CombatAction.heavy).length >= maxHeavy) {
      return false;
    }
    final tail = chain.length >= maxSameInRow
        ? chain.sublist(chain.length - maxSameInRow)
        : const <CombatAction>[];
    return !(tail.length == maxSameInRow && tail.every((x) => x == a));
  }
}

/// Подсказка «кто кого бьёт» (docs/COMBAT.md).
const combatMatchupText =
    'Блок гасит удар в корпус и по ногам и отвечает слабым ударом. Мощный удар '
    'пробивает блок наполовину, захват его ломает.\n'
    'Отход уводит от мощного удара и удара в корпус и бьёт встречным, но удар '
    'по ногам его подсекает.\n'
    'Удары срывают захват. Удар на удар — размен.\n'
    'Мощных — не больше 2 за раунд, одно действие — не больше 3 подряд. '
    'Сила по-прежнему главное: выбор решает при близких силах.';
