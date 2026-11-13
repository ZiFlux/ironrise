import 'body_part.dart';
import 'duel.dart';

/// Сводка одной стороны боя: урон по частям тела, криты, промахи, лечение.
class DuelSide {
  DuelSide(Iterable<DuelHit> hits) {
    for (final h in hits) {
      if (h.damage > 0) {
        damageByPart[h.part] = (damageByPart[h.part] ?? 0) + h.damage;
      }
      if (h.kind == HitKind.crit) crits++;
      if (h.kind == HitKind.miss) misses++;
      heal += h.heal;
    }
  }

  final damageByPart = <BodyPart, int>{};
  var crits = 0;
  var misses = 0;
  var heal = 0;

  int get total => damageByPart.values.fold(0, (a, b) => a + b);

  /// Часть тела, которая нанесла больше всего урона.
  BodyPart? get best => damageByPart.isEmpty
      ? null
      : damageByPart.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// «Почему победил»: урон обеих сторон и короткое объяснение исхода.
class DuelBreakdown {
  DuelBreakdown(this.duel)
    : me = DuelSide(duel.hits.where((h) => h.byAttacker)),
      them = DuelSide(duel.hits.where((h) => !h.byAttacker));

  final DuelResult duel;
  final DuelSide me;
  final DuelSide them;

  /// Две-три фразы: что решило бой.
  List<String> get reasons {
    final out = <String>[];
    final best = me.best;
    if (best != null) {
      out.add(
        'Твой главный удар — ${best.label.toLowerCase()}: '
        '${me.damageByPart[best]} урона из ${me.total}',
      );
    }
    if (me.crits != them.crits) {
      out.add('Критов: у тебя ${me.crits}, у соперника ${them.crits}');
    }
    final pa = duel.attacker.power;
    final pd = duel.defender.power;
    if (pa > 0 && pd > 0 && (pa - pd).abs() / pd >= 0.05) {
      final diff = ((pa - pd).abs() / (pa < pd ? pa : pd) * 100).round();
      out.add(
        pa > pd
            ? 'Ты сильнее на $diff% — перевес в силе решает большинство боёв'
            : duel.attackerWon
            ? 'Соперник был сильнее на $diff%, но удача и события были на твоей стороне'
            : 'Соперник сильнее на $diff%: подтяни отстающие части тела',
      );
    }
    if (me.heal + them.heal > 0) {
      out.add(
        'Восстановлено событиями: у тебя ${me.heal}, у соперника ${them.heal}',
      );
    }
    return out;
  }
}
