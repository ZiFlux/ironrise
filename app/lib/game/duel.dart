import 'dart:math';

import 'body_part.dart';
import 'game_config.dart';
import 'progression.dart';

/// Участник дуэли: игрок или бот.
class Fighter {
  const Fighter({
    required this.id,
    required this.name,
    required this.levels,
    required this.streakDays,
    this.isFemale = false,
  });

  final String id;
  final String name;
  final Map<BodyPart, int> levels;
  final int streakDays;
  final bool isFemale;

  int get power => Progression.power(levels, streakDays);
}

enum HitKind { miss, hit, crit }

class DuelHit {
  const DuelHit({
    required this.byAttacker,
    required this.part,
    required this.kind,
    required this.damage,
    required this.targetHpAfter,
  });

  /// true — бьёт игрок (атакующий), false — соперник.
  final bool byAttacker;
  final BodyPart part;
  final HitKind kind;
  final int damage;
  final int targetHpAfter;
}

class DuelResult {
  const DuelResult({
    required this.attacker,
    required this.defender,
    required this.hits,
    required this.attackerWon,
  });

  final Fighter attacker;
  final Fighter defender;
  final List<DuelHit> hits;
  final bool attackerWon;

  int get attackerHpLeft => _lastHp(byAttacker: false, fallback: attacker.power);
  int get defenderHpLeft => _lastHp(byAttacker: true, fallback: defender.power);

  int _lastHp({required bool byAttacker, required int fallback}) {
    for (final h in hits.reversed) {
      if (h.byAttacker == byAttacker) return h.targetHpAfter;
    }
    return fallback;
  }
}

/// Бой по ТЗ 4.5: HP = P, на каждом ходу атакующая часть выбирается
/// с весом по уровню, dmg = P/20 · (1 + L_part/avgL)/2 · rand(0.85..1.15).
/// Промах и крит дают разброс, чтобы перевес в 20% выигрывал ≈ 85% боёв.
/// Никто не падает за 6–10 ходов, побеждает тот, у кого больше доля HP.
class DuelSimulator {
  const DuelSimulator._();

  static DuelResult fight(Fighter attacker, Fighter defender, int seed) {
    final rng = Random(seed);
    final rounds = GameConfig.duelMinRounds +
        rng.nextInt(GameConfig.duelMaxRounds - GameConfig.duelMinRounds + 1);
    var hpA = attacker.power;
    var hpD = defender.power;
    final hits = <DuelHit>[];

    for (var r = 0; r < rounds; r++) {
      final a = _strike(attacker, rng);
      hpD = max(0, hpD - a.$3);
      hits.add(DuelHit(byAttacker: true, part: a.$1, kind: a.$2, damage: a.$3, targetHpAfter: hpD));

      final d = _strike(defender, rng);
      hpA = max(0, hpA - d.$3);
      hits.add(DuelHit(byAttacker: false, part: d.$1, kind: d.$2, damage: d.$3, targetHpAfter: hpA));
    }

    final shareA = hpA / max(1, attacker.power);
    final shareD = hpD / max(1, defender.power);
    final won = shareA != shareD ? shareA > shareD : attacker.power >= defender.power;
    return DuelResult(attacker: attacker, defender: defender, hits: hits, attackerWon: won);
  }

  static (BodyPart, HitKind, int) _strike(Fighter f, Random rng) {
    final part = _pickPart(f.levels, rng);
    final roll = rng.nextDouble();
    if (roll < GameConfig.duelMissChance) return (part, HitKind.miss, 0);
    final crit = roll > 1 - GameConfig.duelCritChance;
    final avg = Progression.averageLevel(f.levels);
    final spread = 0.85 + rng.nextDouble() * 0.3;
    final base = f.power / 20 * (1 + f.levels[part]! / avg) / 2 * spread;
    final dmg = (base * (crit ? GameConfig.duelCritMultiplier : 1)).round();
    return (part, crit ? HitKind.crit : HitKind.hit, max(1, dmg));
  }

  static BodyPart _pickPart(Map<BodyPart, int> levels, Random rng) {
    final total = levels.values.fold<int>(0, (a, b) => a + b);
    var x = rng.nextInt(total);
    for (final e in levels.entries) {
      if (x < e.value) return e.key;
      x -= e.value;
    }
    return levels.keys.last;
  }
}

/// Боты для офлайн-дуэлей, пока нет сервера и друзей.
/// Набор меняется раз в день и подстраивается под силу игрока.
class DuelBots {
  const DuelBots._();

  static const _names = [
    'Кирпич', 'Штанга', 'Железный Лёха', 'Медведь', 'Пружина', 'Турник',
    'Гиря', 'Рельс', 'Фитоняша', 'Атлант', 'Бицепс', 'Блин 20',
  ];

  /// Соперники от слабого к сильному: ×0.8, ×0.95, ×1.05, ×1.2 от уровней игрока.
  static const _ratios = [0.8, 0.95, 1.05, 1.2];

  static List<Fighter> forDay(Fighter player, DateTime day) {
    final seed = day.year * 10000 + day.month * 100 + day.day;
    final rng = Random(seed);
    final names = [..._names]..shuffle(rng);
    return [
      for (final (i, ratio) in _ratios.indexed)
        Fighter(
          id: 'bot_${seed}_$i',
          name: names[i],
          isFemale: rng.nextBool(),
          streakDays: player.streakDays,
          levels: _scaledLevels(player.levels, ratio, rng, withWeakPart: i.isOdd),
        ),
    ];
  }

  static Map<BodyPart, int> _scaledLevels(
    Map<BodyPart, int> base,
    double ratio,
    Random rng, {
    required bool withWeakPart,
  }) {
    final levels = {
      for (final e in base.entries)
        e.key: max(1, (e.value * ratio + rng.nextDouble() - 0.5).round()),
    };
    if (withWeakPart) {
      // Один отстающий у части ботов: видно, как перекос режет силу.
      final part = BodyPart.values[rng.nextInt(BodyPart.values.length)];
      final avg = Progression.averageLevel(levels);
      final weak = (avg - GameConfig.laggingThreshold - 1).floor();
      if (weak >= 1) {
        final lost = levels[part]! - weak;
        levels[part] = weak;
        // Чтобы бот не стал слабее задуманного, потерянное раздаём остальным.
        final others = BodyPart.values.where((p) => p != part).toList();
        for (var k = 0; k < lost; k++) {
          final p = others[k % others.length];
          levels[p] = levels[p]! + 1;
        }
      }
    }
    return levels;
  }
}

/// Совет после боя: что даст больше всего силы.
class DuelAdvice {
  const DuelAdvice._();

  static String forPlayer(Fighter player) {
    final levels = player.levels;
    final lagging = Progression.laggingParts(levels);
    final now = Progression.power(levels, player.streakDays);
    if (lagging.isNotEmpty) {
      final avg = Progression.averageLevel(levels);
      final fixed = {
        for (final e in levels.entries)
          e.key: lagging.contains(e.key) ? max(e.value, avg.ceil()) : e.value,
      };
      final gain = Progression.power(fixed, player.streakDays) - now;
      final names = lagging.map((p) => p.label.toLowerCase()).join(', ');
      return 'Подтяни $names до среднего — это +$gain силы и бонус баланса';
    }
    final weakest = levels.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
    final next = Progression.power({...levels, weakest: levels[weakest]! + 1}, player.streakDays);
    if (player.streakDays < GameConfig.streakCap) {
      return '+1 уровень «${weakest.label}» даст +${next - now} силы. Не теряй серию: каждый день +2';
    }
    return '+1 уровень «${weakest.label}» даст +${next - now} силы';
  }
}
