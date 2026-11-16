import 'body_part.dart';

/// День восстановления в формате «Минимум» (TRAINING_SYSTEM.md 13.6): 10–15 минут
/// дома — лёгкое кардио, растяжка мышц, которые работали в загрузку, дыхание и
/// кор, если его не грузили. Не силовая: мышцам из загрузки нужно восстановиться.
class RecoveryMove {
  const RecoveryMove(this.name, this.how, this.seconds, {this.part});

  final String name;
  final String how;

  /// Сколько примерно занимает (для подсказки и общего времени).
  final int seconds;

  /// Какую часть тела растягивает; null — общее (кардио, дыхание).
  final BodyPart? part;
}

const _cardio = RecoveryMove(
  'Лёгкое кардио',
  'Ходьба, велосипед или шаг на месте — дыхание ровное, можно разговаривать',
  600,
);

const _breathing = RecoveryMove(
  'Дыхание 4–4–6',
  'Вдох носом 4 счёта, пауза 4, медленный выдох 6. Плечи расслаблены',
  120,
);

const _core = RecoveryMove(
  '«Мёртвый жук»',
  'Лёжа на спине, поясница прижата: медленно опускай противоположные руку и ногу. 2 × 8 на сторону',
  120,
  part: BodyPart.core,
);

const _stretches = <BodyPart, List<RecoveryMove>>{
  BodyPart.chest: [
    RecoveryMove(
      'Растяжка груди у стены',
      'Предплечье на стене на уровне плеча, мягко повернись корпусом от стены. 30 с на сторону',
      60,
      part: BodyPart.chest,
    ),
  ],
  BodyPart.arms: [
    RecoveryMove(
      'Растяжка трицепса',
      'Рука за головой, локоть вверх, другой рукой мягко тяни локоть. 30 с на сторону',
      60,
      part: BodyPart.arms,
    ),
    RecoveryMove(
      'Растяжка бицепса и предплечья',
      'Прямая рука ладонью вперёд, другой рукой мягко отводи пальцы на себя. 30 с на сторону',
      60,
      part: BodyPart.arms,
    ),
  ],
  BodyPart.back: [
    RecoveryMove(
      'Поза ребёнка',
      'Сядь на пятки, руки вперёд по полу, лоб вниз. Дыши в спину. 45 с',
      45,
      part: BodyPart.back,
    ),
    RecoveryMove(
      '«Кошка-корова»',
      'На четвереньках медленно округляй и прогибай спину. 10 раз',
      45,
      part: BodyPart.back,
    ),
  ],
  BodyPart.legs: [
    RecoveryMove(
      'Растяжка передней поверхности бедра',
      'Стоя, держись за опору, пятку к ягодице, колени рядом. 30 с на сторону',
      60,
      part: BodyPart.legs,
    ),
    RecoveryMove(
      'Наклон к прямой ноге',
      'Нога на невысокой опоре, спина прямая, наклон от таза до лёгкого натяжения. 30 с на сторону',
      60,
      part: BodyPart.legs,
    ),
    RecoveryMove(
      'Растяжка икр у стены',
      'Руки в стену, одна нога назад, пятка в пол. 30 с на сторону',
      60,
      part: BodyPart.legs,
    ),
  ],
  BodyPart.core: [
    RecoveryMove(
      '«Кобра»',
      'Лёжа на животе, мягко приподнимись на предплечьях, живот расслаблен. 30 с',
      30,
      part: BodyPart.core,
    ),
  ],
};

/// План восстановления: кардио, растяжка частей из загрузки ([trained]),
/// кор — если его не грузили, и дыхание в конце.
List<RecoveryMove> recoveryPlan(Set<BodyPart> trained) {
  final parts = trained.isEmpty
      ? {BodyPart.chest, BodyPart.back, BodyPart.legs}
      : trained;
  return [
    _cardio,
    for (final p in BodyPart.values)
      if (parts.contains(p)) ...?_stretches[p],
    if (!parts.contains(BodyPart.core)) _core,
    _breathing,
  ];
}

int recoveryMinutes(List<RecoveryMove> plan) =>
    (plan.fold<int>(0, (s, m) => s + m.seconds) / 60).round();
